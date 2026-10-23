/*
 * sqrlfk.sys: Windows KMDF driver for the SQRL Forest Kitten FK33/FK35 example design (PCI 1E24:1533).
 *
 * - MCAP (Media Configuration Access Port) registers in PCI configuration space, so sqrl_fk_mcap.exe can load
 *   a PCIe Tandem stage 2 bitstream. Only the MCAP control and write data registers can be written.
 * - 32-bit register access to the memory BARs (BAR0 is the XDMA AXI-Lite master: DNA, I2C, system monitor).
 * - XDMA transfers between a DMA common buffer and the card's AXI memory (HBM, DMA loop test BRAM): one polled
 *   descriptor per request on channel 0; the XDMA interrupts stay disabled.
 *
 * \Device\SqrlFk<n> (\\.\SqrlFk<n>), n = 0 for the first board; only SYSTEM and Administrators can open it.
 * Requests go through one sequential, power-managed queue at PASSIVE_LEVEL. The framework stops the queue before
 * the hardware is released, so the request handlers need no locks. Built with the WDK (build.bat, Enterprise WDK).
 */
#include <ntddk.h>
#include <wdf.h>
#include <ntstrsafe.h>
#include <initguid.h>
#include <wdmguid.h>
#include "sqrlfk_ioctl.h"

#define MCAP_VSEC_ID        0x0001      /* Xilinx MCAP vendor-specific extended capability */
#define MCAP_CONTROL        0x14
#define MCAP_WRITE_DATA     0x18
#define MAX_BAR_MAP         (16 * 1024 * 1024)

/* XDMA DMA BAR (PG195; register names as in Xilinx's libxdma.h). */
#define XDMA_BAR_SIZE       0x10000
#define XDMA_H2C            0x0000      /* channel registers, + 0x100 per channel */
#define XDMA_C2H            0x1000
#define XDMA_IRQ            0x2000
#define XDMA_SGDMA          0x4000      /* + channel register offset */
#define XDMA_ID             0x00
#define XDMA_CONTROL        0x04
#define XDMA_STATUS         0x40
#define XDMA_STATUS_RC      0x44        /* read clears the status */
#define XDMA_DESC_LO        0x80        /* SGDMA: first descriptor bus address */
#define XDMA_DESC_HI        0x84
#define XDMA_DESC_ADJACENT  0x88
#define XDMA_IRQ_USER_W1C   0x0C        /* IRQ block: user and channel interrupt enable masks, write 1 to clear */
#define XDMA_IRQ_CHAN_W1C   0x18
#define XDMA_RUN            0x00000001
#define XDMA_IE             0x00F83E1E  /* status logging: descriptor stopped/completed, alignment, magic, read and
                                           descriptor errors (no interrupt while the IRQ block masks are clear) */
#define XDMA_BUSY           0x00000001
#define XDMA_STOPPED        0x00000002
#define XDMA_COMPLETED      0x00000004
#define XDMA_IDLE_STOPPED   0x00000040
#define XDMA_DESC_CONTROL   0xAD4B0013  /* magic, one descriptor: STOPPED | COMPLETED | EOP */
#define DMA_DESC_SPACE      4096        /* descriptor at the start of the common buffer, data after it */

typedef struct _XDMA_DESC {
    ULONG Control;
    ULONG Bytes;
    ULONG SrcLo;
    ULONG SrcHi;
    ULONG DstLo;
    ULONG DstHi;
    ULONG NextLo;
    ULONG NextHi;
} XDMA_DESC;

typedef struct _SQRLFK_BAR {
    ULONGLONG Address;      /* bus address (raw resource) */
    PVOID Va;               /* kernel mapping, NULL if not mapped */
    ULONG Length;
} SQRLFK_BAR;

typedef struct _SQRLFK_CTX {
    BUS_INTERFACE_STANDARD Bus;
    BOOLEAN HaveBus;
    BOOLEAN HaveIndex;
    LONG Index;
    ULONG BusNumber;
    ULONG Address;          /* device << 16 | function */
    ULONG McapOffset;
    SQRLFK_BAR Bar[SQRLFK_MAX_BARS];
    ULONG DmaBar;           /* BAR with the XDMA registers, SQRLFK_NO_BAR if none */
    WDFDMAENABLER DmaEnabler;
    WDFCOMMONBUFFER DmaBuffer;
    PUCHAR DmaVa;           /* common buffer: descriptor, then DmaSize bytes of data */
    PHYSICAL_ADDRESS DmaPa;
    ULONG DmaSize;
} SQRLFK_CTX;

WDF_DECLARE_CONTEXT_TYPE_WITH_NAME(SQRLFK_CTX, GetCtx)

DRIVER_INITIALIZE DriverEntry;
EVT_WDF_DRIVER_DEVICE_ADD SqrlFkDeviceAdd;
EVT_WDF_DEVICE_PREPARE_HARDWARE SqrlFkPrepareHardware;
EVT_WDF_DEVICE_RELEASE_HARDWARE SqrlFkReleaseHardware;
EVT_WDF_OBJECT_CONTEXT_CLEANUP SqrlFkDeviceCleanup;
EVT_WDF_IO_QUEUE_IO_DEVICE_CONTROL SqrlFkIoDeviceControl;

static volatile LONG g_UsedIndexes;      /* bit n: \Device\SqrlFk<n> exists */

/* Lowest free board index, -1 if all 32 are used. */
static LONG AllocIndex(void)
{
    for (;;) {
        LONG used = InterlockedOr(&g_UsedIndexes, 0), i;
        for (i = 0; i < 32 && (used & (1L << i)); i++)
            ;
        if (i == 32)
            return -1;
        if (InterlockedCompareExchange(&g_UsedIndexes, used | (1L << i), used) == used)
            return i;
    }
}

static void FreeIndex(LONG index)
{
    InterlockedAnd(&g_UsedIndexes, ~(1L << index));
}

static ULONG CfgRead(SQRLFK_CTX *x, ULONG offset, PVOID buffer, ULONG length)
{
    return x->Bus.GetBusData(x->Bus.Context, PCI_WHICHSPACE_CONFIG, buffer, offset, length);
}

static ULONG CfgWrite(SQRLFK_CTX *x, ULONG offset, ULONG value)
{
    return x->Bus.SetBusData(x->Bus.Context, PCI_WHICHSPACE_CONFIG, &value, offset, sizeof(value));
}

/* XDMA needs bus mastering; a 16-bit write leaves the status register (RW1C bits) alone. */
static void EnableBusMaster(SQRLFK_CTX *x)
{
    USHORT command;

    if (CfgRead(x, 4, &command, sizeof(command)) == sizeof(command) && !(command & 4)) {
        command |= 4;
        x->Bus.SetBusData(x->Bus.Context, PCI_WHICHSPACE_CONFIG, &command, 4, sizeof(command));
    }
}

/* Walks the PCIe extended capabilities for the Xilinx MCAP VSEC; 0 if the design has none. */
static ULONG FindMcap(SQRLFK_CTX *x)
{
    ULONG offset = 0x100, header, vsec;
    int n;

    for (n = 0; n < 64 && offset >= 0x100 && offset <= 0xFFC; n++) {
        if (CfgRead(x, offset, &header, 4) != 4 || header == 0 || header == 0xFFFFFFFF)
            break;
        if ((header & 0xFFFF) == 0x000B && CfgRead(x, offset + 4, &vsec, 4) == 4 && (vsec & 0xFFFF) == MCAP_VSEC_ID)
            return offset;
        offset = (header >> 20) & 0xFFC;
    }
    return 0;
}

/* Maps each memory BAR: its address in configuration space selects the raw resource, and the translated resource
   at the same index is mapped. */
static void MapBars(SQRLFK_CTX *x, WDFCMRESLIST raw, WDFCMRESLIST translated)
{
    ULONG bars[SQRLFK_MAX_BARS], i, j, count = WdfCmResourceListGetCount(raw);

    if (CfgRead(x, 0x10, bars, sizeof(bars)) != sizeof(bars))
        return;
    for (i = 0; i < SQRLFK_MAX_BARS; i++) {
        BOOLEAN is64 = (bars[i] & 0x7) == 0x4;
        ULONGLONG address = bars[i] & ~0xFULL;
        if (bars[i] & 1)                        /* I/O BAR */
            continue;
        if (is64 && i + 1 < SQRLFK_MAX_BARS)
            address |= (ULONGLONG)bars[i + 1] << 32;
        for (j = 0; address != 0 && j < count; j++) {
            PCM_PARTIAL_RESOURCE_DESCRIPTOR rp = WdfCmResourceListGetDescriptor(raw, j);
            PCM_PARTIAL_RESOURCE_DESCRIPTOR tp = WdfCmResourceListGetDescriptor(translated, j);
            if (rp == NULL || tp == NULL || rp->Type != CmResourceTypeMemory || tp->Type != CmResourceTypeMemory ||
                (ULONGLONG)rp->u.Memory.Start.QuadPart != address)
                continue;
            if (tp->u.Memory.Length != 0 && tp->u.Memory.Length <= MAX_BAR_MAP) {
                x->Bar[i].Va = MmMapIoSpaceEx(tp->u.Memory.Start, tp->u.Memory.Length, PAGE_READWRITE | PAGE_NOCACHE);
                if (x->Bar[i].Va != NULL) {
                    x->Bar[i].Address = address;
                    x->Bar[i].Length = tp->u.Memory.Length;
                }
            }
            break;
        }
        if (is64)
            i++;
    }
}

static ULONG XdmaRead(SQRLFK_CTX *x, ULONG offset)
{
    return READ_REGISTER_ULONG((PULONG)((PUCHAR)x->Bar[x->DmaBar].Va + offset));
}

static void XdmaWrite(SQRLFK_CTX *x, ULONG offset, ULONG value)
{
    WRITE_REGISTER_ULONG((PULONG)((PUCHAR)x->Bar[x->DmaBar].Va + offset), value);
}

/* One XDMA transfer of <length> bytes between the data part of the common buffer and <card> (AXI address), polled. */
static void RunDma(SQRLFK_CTX *x, BOOLEAN c2h, ULONG channel, ULONGLONG card, ULONG length, SQRLFK_DMA_RESULT *r)
{
    ULONG engine = (c2h ? XDMA_C2H : XDMA_H2C) + channel * 0x100, status;
    ULONGLONG host = (ULONGLONG)x->DmaPa.QuadPart + DMA_DESC_SPACE;
    ULONGLONG src = c2h ? card : host, dst = c2h ? host : card;
    XDMA_DESC *d = (XDMA_DESC *)x->DmaVa;
    LARGE_INTEGER t0, t1, freq;

    RtlZeroMemory(r, sizeof(*r));
    /* Identifier 0x1FC0xxxx for H2C, 0x1FC1xxxx for C2H: missing until stage 2 is loaded. */
    if ((XdmaRead(x, engine + XDMA_ID) >> 16) != (c2h ? 0x1FC1u : 0x1FC0u)) {
        r->Error = SQRLFK_DMA_NO_ENGINE;
        return;
    }
    /* No interrupts: this driver has no interrupt handler. */
    XdmaWrite(x, XDMA_IRQ + XDMA_IRQ_USER_W1C, 0xFFFFFFFF);
    XdmaWrite(x, XDMA_IRQ + XDMA_IRQ_CHAN_W1C, 0xFFFFFFFF);

    d->Control = XDMA_DESC_CONTROL;
    d->Bytes = length;
    d->SrcLo = (ULONG)src;
    d->SrcHi = (ULONG)(src >> 32);
    d->DstLo = (ULONG)dst;
    d->DstHi = (ULONG)(dst >> 32);
    d->NextLo = 0;
    d->NextHi = 0;
    KeMemoryBarrier();      /* descriptor in memory before the engine starts */

    XdmaWrite(x, engine + XDMA_CONTROL, 0);
    (void)XdmaRead(x, engine + XDMA_STATUS_RC);
    XdmaWrite(x, XDMA_SGDMA + engine + XDMA_DESC_LO, (ULONG)x->DmaPa.QuadPart);
    XdmaWrite(x, XDMA_SGDMA + engine + XDMA_DESC_HI, (ULONG)((ULONGLONG)x->DmaPa.QuadPart >> 32));
    XdmaWrite(x, XDMA_SGDMA + engine + XDMA_DESC_ADJACENT, 0);
    t0 = KeQueryPerformanceCounter(&freq);
    XdmaWrite(x, engine + XDMA_CONTROL, XDMA_RUN | XDMA_IE);
    for (;;) {
        status = XdmaRead(x, engine + XDMA_STATUS);
        t1 = KeQueryPerformanceCounter(NULL);
        if (status & ~(XDMA_BUSY | XDMA_STOPPED | XDMA_COMPLETED | XDMA_IDLE_STOPPED)) {
            r->Error = SQRLFK_DMA_ERROR;
            break;
        }
        if ((status & XDMA_STOPPED) && !(status & XDMA_BUSY))
            break;
        if (t1.QuadPart - t0.QuadPart > 2 * freq.QuadPart) {
            r->Error = SQRLFK_DMA_TIMEOUT;
            break;
        }
    }
    XdmaWrite(x, engine + XDMA_CONTROL, 0);
    r->EngineStatus = status;
    r->Nanoseconds = (ULONGLONG)(t1.QuadPart - t0.QuadPart) * 1000000000ULL / (ULONGLONG)freq.QuadPart;
}

static NTSTATUS DoIoctl(SQRLFK_CTX *x, ULONG code, PVOID buffer, ULONG inLength, ULONG outLength, ULONG_PTR *info)
{
    SQRLFK_ACCESS *a = (SQRLFK_ACCESS *)buffer;
    PULONG words = (PULONG)buffer;
    ULONG value, i;

    switch (code) {
    case IOCTL_SQRLFK_GET_INFO: {
        SQRLFK_INFO *out = (SQRLFK_INFO *)buffer;
        if (outLength < sizeof(SQRLFK_INFO))
            return STATUS_BUFFER_TOO_SMALL;
        RtlZeroMemory(out, sizeof(*out));
        out->Version = SQRLFK_VERSION;
        CfgRead(x, 0, &out->VendorDevice, 4);
        out->BusNumber = x->BusNumber;
        out->Address = x->Address;
        out->McapOffset = x->McapOffset;
        out->DmaBar = x->DmaBar;
        for (i = 0; i < SQRLFK_MAX_BARS; i++) {
            out->BarAddress[i] = x->Bar[i].Address;
            out->BarLength[i] = x->Bar[i].Length;
        }
        out->DmaBufferSize = x->DmaBar != SQRLFK_NO_BAR ? x->DmaSize : 0;
        *info = sizeof(SQRLFK_INFO);
        return STATUS_SUCCESS;
    }

    case IOCTL_SQRLFK_CFG_READ:
        if (inLength < sizeof(ULONG) || outLength < sizeof(ULONG))
            return STATUS_BUFFER_TOO_SMALL;
        if (words[0] > 0xFFC || (words[0] & 3))
            return STATUS_INVALID_PARAMETER;
        if (CfgRead(x, words[0], &value, 4) != 4)
            return STATUS_IO_DEVICE_ERROR;
        words[0] = value;
        *info = sizeof(ULONG);
        return STATUS_SUCCESS;

    case IOCTL_SQRLFK_MCAP_WRITE:
        if (inLength < sizeof(SQRLFK_ACCESS))
            return STATUS_BUFFER_TOO_SMALL;
        if (x->McapOffset == 0)
            return STATUS_NOT_SUPPORTED;
        if (a->Offset != MCAP_CONTROL && a->Offset != MCAP_WRITE_DATA)
            return STATUS_ACCESS_DENIED;
        return CfgWrite(x, x->McapOffset + a->Offset, a->Value) == 4 ? STATUS_SUCCESS : STATUS_IO_DEVICE_ERROR;

    case IOCTL_SQRLFK_MCAP_DATA:
        if (inLength == 0 || (inLength & 3) || inLength > SQRLFK_MCAP_DATA_MAX)
            return STATUS_INVALID_PARAMETER;
        if (x->McapOffset == 0)
            return STATUS_NOT_SUPPORTED;
        /* Same pacing as the Xilinx MCAP driver: 1 us after each word. */
        for (i = 0; i < inLength / 4; i++) {
            if (CfgWrite(x, x->McapOffset + MCAP_WRITE_DATA, words[i]) != 4)
                return STATUS_IO_DEVICE_ERROR;
            KeStallExecutionProcessor(1);
        }
        return STATUS_SUCCESS;

    case IOCTL_SQRLFK_BAR_READ:
    case IOCTL_SQRLFK_BAR_WRITE:
        if (inLength < sizeof(SQRLFK_ACCESS))
            return STATUS_BUFFER_TOO_SMALL;
        if (a->Bar >= SQRLFK_MAX_BARS || x->Bar[a->Bar].Va == NULL)
            return STATUS_NOT_SUPPORTED;
        if ((a->Offset & 3) || a->Offset > x->Bar[a->Bar].Length - 4)
            return STATUS_INVALID_PARAMETER;
        if (code == IOCTL_SQRLFK_BAR_WRITE) {
            WRITE_REGISTER_ULONG((PULONG)((PUCHAR)x->Bar[a->Bar].Va + a->Offset), a->Value);
            return STATUS_SUCCESS;
        }
        if (outLength < sizeof(ULONG))
            return STATUS_BUFFER_TOO_SMALL;
        words[0] = READ_REGISTER_ULONG((PULONG)((PUCHAR)x->Bar[a->Bar].Va + a->Offset));
        *info = sizeof(ULONG);
        return STATUS_SUCCESS;

    case IOCTL_SQRLFK_DMA_WRITE:
    case IOCTL_SQRLFK_DMA_READ: {
        BOOLEAN c2h = code == IOCTL_SQRLFK_DMA_READ;
        SQRLFK_DMA request;
        SQRLFK_DMA_RESULT result;

        if (inLength < sizeof(SQRLFK_DMA))
            return STATUS_BUFFER_TOO_SMALL;
        request = *(SQRLFK_DMA *)buffer;
        if (x->DmaBar == SQRLFK_NO_BAR || x->DmaVa == NULL)
            return STATUS_NOT_SUPPORTED;
        if (request.Length == 0 || (request.Length & 3) || request.Length > x->DmaSize || request.Channel > 3)
            return STATUS_INVALID_PARAMETER;
        if (c2h ? outLength < sizeof(SQRLFK_DMA_RESULT) + request.Length :
                  inLength < sizeof(SQRLFK_DMA) + request.Length || outLength < sizeof(SQRLFK_DMA_RESULT))
            return STATUS_BUFFER_TOO_SMALL;
        if (!c2h)
            RtlCopyMemory(x->DmaVa + DMA_DESC_SPACE, (PUCHAR)buffer + sizeof(SQRLFK_DMA), request.Length);
        RunDma(x, c2h, request.Channel, request.CardAddress, request.Length, &result);
        *(SQRLFK_DMA_RESULT *)buffer = result;
        *info = sizeof(SQRLFK_DMA_RESULT);
        if (c2h && result.Error == SQRLFK_DMA_OK) {
            RtlCopyMemory((PUCHAR)buffer + sizeof(SQRLFK_DMA_RESULT), x->DmaVa + DMA_DESC_SPACE, request.Length);
            *info += request.Length;
        }
        return STATUS_SUCCESS;
    }

    default:
        return STATUS_INVALID_DEVICE_REQUEST;
    }
}

VOID SqrlFkIoDeviceControl(WDFQUEUE queue, WDFREQUEST request, size_t outLength, size_t inLength, ULONG code)
{
    SQRLFK_CTX *x = GetCtx(WdfIoQueueGetDevice(queue));
    PVOID buffer = NULL;
    ULONG_PTR info = 0;
    NTSTATUS st = STATUS_SUCCESS;

    /* METHOD_BUFFERED: input and output share one system buffer. */
    if (inLength > 0)
        st = WdfRequestRetrieveInputBuffer(request, 0, &buffer, NULL);
    else if (outLength > 0)
        st = WdfRequestRetrieveOutputBuffer(request, 0, &buffer, NULL);
    if (NT_SUCCESS(st)) {
        if (!x->HaveBus)
            st = STATUS_DEVICE_NOT_READY;
        else if (buffer == NULL && code != IOCTL_SQRLFK_GET_INFO)
            st = STATUS_INVALID_PARAMETER;
        else
            st = DoIoctl(x, code, buffer, (ULONG)inLength, (ULONG)outLength, &info);
    }
    WdfRequestCompleteWithInformation(request, st, NT_SUCCESS(st) ? info : 0);
}

NTSTATUS SqrlFkPrepareHardware(WDFDEVICE device, WDFCMRESLIST raw, WDFCMRESLIST translated)
{
    SQRLFK_CTX *x = GetCtx(device);
    ULONG length, i;
    NTSTATUS st;

    st = WdfFdoQueryForInterface(device, &GUID_BUS_INTERFACE_STANDARD, (PINTERFACE)&x->Bus,
                                 sizeof(BUS_INTERFACE_STANDARD), 1, NULL);
    if (!NT_SUCCESS(st))
        return st;
    x->HaveBus = TRUE;
    if (!NT_SUCCESS(WdfDeviceQueryProperty(device, DevicePropertyBusNumber, sizeof(ULONG), &x->BusNumber, &length)))
        x->BusNumber = 0;
    if (!NT_SUCCESS(WdfDeviceQueryProperty(device, DevicePropertyAddress, sizeof(ULONG), &x->Address, &length)))
        x->Address = 0;
    x->McapOffset = FindMcap(x);
    MapBars(x, raw, translated);
    /* The XDMA DMA BAR is 64 KB (the AXI-Lite BAR of this design is 128 KB). */
    x->DmaBar = SQRLFK_NO_BAR;
    for (i = 0; i < SQRLFK_MAX_BARS && x->DmaBar == SQRLFK_NO_BAR; i++)
        if (x->Bar[i].Va != NULL && x->Bar[i].Length == XDMA_BAR_SIZE)
            x->DmaBar = i;
    if (x->DmaBar != SQRLFK_NO_BAR && x->DmaVa != NULL)
        EnableBusMaster(x);
    return STATUS_SUCCESS;
}

NTSTATUS SqrlFkReleaseHardware(WDFDEVICE device, WDFCMRESLIST translated)
{
    SQRLFK_CTX *x = GetCtx(device);
    ULONG i;

    UNREFERENCED_PARAMETER(translated);
    x->DmaBar = SQRLFK_NO_BAR;
    for (i = 0; i < SQRLFK_MAX_BARS; i++) {
        if (x->Bar[i].Va != NULL)
            MmUnmapIoSpace(x->Bar[i].Va, x->Bar[i].Length);
        x->Bar[i].Va = NULL;
        x->Bar[i].Address = 0;
        x->Bar[i].Length = 0;
    }
    if (x->HaveBus) {
        x->Bus.InterfaceDereference(x->Bus.Context);
        x->HaveBus = FALSE;
    }
    return STATUS_SUCCESS;
}

VOID SqrlFkDeviceCleanup(WDFOBJECT object)
{
    SQRLFK_CTX *x = GetCtx((WDFDEVICE)object);

    if (x->HaveIndex)
        FreeIndex(x->Index);
}

NTSTATUS SqrlFkDeviceAdd(WDFDRIVER driver, PWDFDEVICE_INIT init)
{
    DECLARE_CONST_UNICODE_STRING(sddl, L"D:P(A;;GA;;;SY)(A;;GA;;;BA)");
    DECLARE_UNICODE_STRING_SIZE(name, 32);
    DECLARE_UNICODE_STRING_SIZE(link, 32);
    WDF_PNPPOWER_EVENT_CALLBACKS pnp;
    WDF_OBJECT_ATTRIBUTES attributes;
    WDF_IO_QUEUE_CONFIG queue;
    WDF_DMA_ENABLER_CONFIG dma;
    WDFDEVICE device;
    SQRLFK_CTX *x;
    NTSTATUS st;
    ULONG size;
    LONG index = AllocIndex();

    UNREFERENCED_PARAMETER(driver);
    if (index < 0)
        return STATUS_INSUFFICIENT_RESOURCES;
    st = RtlUnicodeStringPrintf(&name, L"\\Device\\SqrlFk%d", index);
    if (NT_SUCCESS(st))
        st = RtlUnicodeStringPrintf(&link, L"\\DosDevices\\SqrlFk%d", index);
    if (NT_SUCCESS(st))
        st = WdfDeviceInitAssignName(init, &name);
    if (NT_SUCCESS(st))
        st = WdfDeviceInitAssignSDDLString(init, &sddl);
    if (!NT_SUCCESS(st)) {
        FreeIndex(index);
        return st;
    }
    WdfDeviceInitSetDeviceType(init, FILE_DEVICE_UNKNOWN);
    WdfDeviceInitSetCharacteristics(init, FILE_DEVICE_SECURE_OPEN, TRUE);
    WDF_PNPPOWER_EVENT_CALLBACKS_INIT(&pnp);
    pnp.EvtDevicePrepareHardware = SqrlFkPrepareHardware;
    pnp.EvtDeviceReleaseHardware = SqrlFkReleaseHardware;
    WdfDeviceInitSetPnpPowerEventCallbacks(init, &pnp);

    WDF_OBJECT_ATTRIBUTES_INIT_CONTEXT_TYPE(&attributes, SQRLFK_CTX);
    attributes.ExecutionLevel = WdfExecutionLevelPassive;
    attributes.EvtCleanupCallback = SqrlFkDeviceCleanup;
    st = WdfDeviceCreate(&init, &attributes, &device);
    if (!NT_SUCCESS(st)) {
        FreeIndex(index);
        return st;
    }
    x = GetCtx(device);
    x->Index = index;
    x->HaveIndex = TRUE;
    x->DmaBar = SQRLFK_NO_BAR;

    st = WdfDeviceCreateSymbolicLink(device, &link);
    if (!NT_SUCCESS(st))
        return st;
    WDF_IO_QUEUE_CONFIG_INIT_DEFAULT_QUEUE(&queue, WdfIoQueueDispatchSequential);
    queue.EvtIoDeviceControl = SqrlFkIoDeviceControl;
    st = WdfIoQueueCreate(device, &queue, WDF_NO_OBJECT_ATTRIBUTES, WDF_NO_HANDLE);
    if (!NT_SUCCESS(st))
        return st;

    /* DMA common buffer, 4 MB or less when contiguous memory is short. Without it the board works without DMA. */
    WDF_DMA_ENABLER_CONFIG_INIT(&dma, WdfDmaProfileScatterGather64, SQRLFK_DMA_MAX + DMA_DESC_SPACE);
    if (NT_SUCCESS(WdfDmaEnablerCreate(device, &dma, WDF_NO_OBJECT_ATTRIBUTES, &x->DmaEnabler))) {
        for (size = SQRLFK_DMA_MAX; size >= 256 * 1024; size /= 4) {
            if (NT_SUCCESS(WdfCommonBufferCreate(x->DmaEnabler, size + DMA_DESC_SPACE, WDF_NO_OBJECT_ATTRIBUTES,
                                                 &x->DmaBuffer))) {
                x->DmaVa = (PUCHAR)WdfCommonBufferGetAlignedVirtualAddress(x->DmaBuffer);
                x->DmaPa = WdfCommonBufferGetAlignedLogicalAddress(x->DmaBuffer);
                x->DmaSize = size;
                break;
            }
        }
    }
    return STATUS_SUCCESS;
}

NTSTATUS DriverEntry(PDRIVER_OBJECT driver, PUNICODE_STRING registryPath)
{
    WDF_DRIVER_CONFIG config;

    WDF_DRIVER_CONFIG_INIT(&config, SqrlFkDeviceAdd);
    return WdfDriverCreate(driver, registryPath, WDF_NO_OBJECT_ATTRIBUTES, &config, WDF_NO_HANDLE);
}
