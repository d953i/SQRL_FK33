/*
 * sqrlfk_ioctl.h: interface between sqrlfk.sys and its user-mode tools (sqrl_fk_mcap.exe).
 * Include <windows.h> and <winioctl.h> (user mode) or <ntddk.h> (kernel) first.
 */
#ifndef SQRLFK_IOCTL_H
#define SQRLFK_IOCTL_H

#define SQRLFK_VERSION      0x00020000          /* 2.0: KMDF */
#define SQRLFK_DEVICE_NAME  L"\\\\.\\SqrlFk"     /* + board index 0, 1, ... */
#define SQRLFK_MAX_BARS     6
#define SQRLFK_NO_BAR       0xFFFFFFFF
#define SQRLFK_DMA_MAX      (4 * 1024 * 1024)   /* largest DMA buffer the driver tries to allocate */

/* Custom device type (0x8000-0xFFFF) and function codes (0x800-0xFFF). */
#define SQRLFK_DEVICE_TYPE  0x8A35u     /* unsigned: CTL_CODE shifts it into bit 31 */
#define SQRLFK_IOCTL(fn, access) CTL_CODE(SQRLFK_DEVICE_TYPE, 0x800 + (fn), METHOD_BUFFERED, (access))

/* Out: SQRLFK_INFO. */
#define IOCTL_SQRLFK_GET_INFO   SQRLFK_IOCTL(0, FILE_READ_ACCESS)
/* In: ULONG configuration space offset (dword aligned, below 0x1000). Out: ULONG value. */
#define IOCTL_SQRLFK_CFG_READ   SQRLFK_IOCTL(1, FILE_READ_ACCESS)
/* In: SQRLFK_ACCESS, Offset relative to the MCAP capability: 0x14 (control) or 0x18 (write data) only. */
#define IOCTL_SQRLFK_MCAP_WRITE SQRLFK_IOCTL(2, FILE_READ_ACCESS | FILE_WRITE_ACCESS)
/* In: ULONG words for the MCAP write data register, in order (at most SQRLFK_MCAP_DATA_MAX bytes). */
#define IOCTL_SQRLFK_MCAP_DATA  SQRLFK_IOCTL(3, FILE_READ_ACCESS | FILE_WRITE_ACCESS)
/* In: SQRLFK_ACCESS (Bar, Offset). Out: ULONG value. */
#define IOCTL_SQRLFK_BAR_READ   SQRLFK_IOCTL(4, FILE_READ_ACCESS)
/* In: SQRLFK_ACCESS (Bar, Offset, Value). */
#define IOCTL_SQRLFK_BAR_WRITE  SQRLFK_IOCTL(5, FILE_READ_ACCESS | FILE_WRITE_ACCESS)
/* XDMA host to card. In: SQRLFK_DMA followed by Length bytes. Out: SQRLFK_DMA_RESULT. */
#define IOCTL_SQRLFK_DMA_WRITE  SQRLFK_IOCTL(6, FILE_READ_ACCESS | FILE_WRITE_ACCESS)
/* XDMA card to host. In: SQRLFK_DMA. Out: SQRLFK_DMA_RESULT followed by Length bytes. */
#define IOCTL_SQRLFK_DMA_READ   SQRLFK_IOCTL(7, FILE_READ_ACCESS | FILE_WRITE_ACCESS)

#define SQRLFK_MCAP_DATA_MAX    (1024 * 1024)

typedef struct _SQRLFK_INFO {
    ULONG Version;                      /* SQRLFK_VERSION of the driver */
    ULONG VendorDevice;                 /* configuration dword 0: device ID << 16 | vendor ID */
    ULONG BusNumber;
    ULONG Address;                      /* device number << 16 | function number */
    ULONG McapOffset;                   /* configuration space offset of the MCAP capability, 0 if none */
    ULONG DmaBar;                       /* BAR with the XDMA DMA registers (64 KB), SQRLFK_NO_BAR if none */
    ULONGLONG BarAddress[SQRLFK_MAX_BARS]; /* bus address of each mapped memory BAR, 0 if not mapped */
    ULONG BarLength[SQRLFK_MAX_BARS];
    ULONG DmaBufferSize;                /* largest DMA transfer in bytes, 0 if the driver has no DMA buffer */
    ULONG Reserved;
} SQRLFK_INFO;

typedef struct _SQRLFK_DMA {
    ULONGLONG CardAddress;              /* address on the XDMA AXI port: HBM 0x0, 0x1_0000_0000; BRAM 0x2_0000_0000 */
    ULONG Length;                       /* bytes, a multiple of 4, at most SQRLFK_INFO.DmaBufferSize */
    ULONG Channel;                      /* XDMA channel, 0 */
} SQRLFK_DMA;

#define SQRLFK_DMA_OK           0
#define SQRLFK_DMA_TIMEOUT      1       /* engine did not finish within 2 s */
#define SQRLFK_DMA_ERROR        2       /* engine reported an error (EngineStatus) */
#define SQRLFK_DMA_NO_ENGINE    3       /* no XDMA engine answers: stage 2 not loaded, or no such channel */

typedef struct _SQRLFK_DMA_RESULT {
    ULONG Error;                        /* SQRLFK_DMA_* */
    ULONG EngineStatus;                 /* XDMA channel status register at the end */
    ULONGLONG Nanoseconds;              /* engine run time, from start to descriptor stopped */
} SQRLFK_DMA_RESULT;

typedef struct _SQRLFK_ACCESS {
    ULONG Bar;                          /* BAR number (BAR_READ / BAR_WRITE) */
    ULONG Offset;                       /* byte offset, dword aligned */
    ULONG Value;                        /* value to write */
} SQRLFK_ACCESS;

#endif
