/*
 * sqrl_fk_mcap.exe: SQRL Forest Kitten FK33/FK35 tool for sqrlfk.sys (run as Administrator).
 *
 *   sqrl_fk_mcap info                 board, BARs and MCAP registers
 *   sqrl_fk_mcap load <stage2.bit>    load a PCIe Tandem stage 2 bitstream (.bit or .bin) through MCAP
 *   sqrl_fk_mcap dna                  read the design's device DNA over BAR0
 *   sqrl_fk_mcap read <offset>        read a 32-bit BAR register
 *   sqrl_fk_mcap write <offset> <value>
 *   sqrl_fk_mcap loop [<address> [<bytes>]]
 *                                     XDMA loop test: write a pattern with H2C DMA, read it back with C2H DMA,
 *                                     compare; without an address: the BRAM and both HBM stacks
 *
 * Options (before the command): -d <n> board index (default 0), -b <n> BAR for read/write (default 0),
 * -f load even if the design switch says stage 2 is already loaded, -n <n> loop test iterations (default 10).
 */
#include <windows.h>
#include <winioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "sqrlfk_ioctl.h"

/* MCAP registers (offsets in the capability) and fields, as in Xilinx's XVSEC driver (dma_ip_drivers). */
#define MCAP_EXT_HEADER     0x00
#define MCAP_VSEC_HEADER    0x04
#define MCAP_JTAG_ID        0x08
#define MCAP_BIT_VERSION    0x0C
#define MCAP_STATUS         0x10
#define MCAP_CONTROL        0x14
#define MCAP_WRITE_DATA     0x18

#define CTRL_ENABLE         (1u << 0)
#define CTRL_RD_ENABLE      (1u << 1)
#define CTRL_RESET          (1u << 4)
#define CTRL_MOD_RESET      (1u << 5)
#define CTRL_REQ_ACCESS     (1u << 8)
#define CTRL_CFG_SWITCH     (1u << 12)  /* design switch: BAR accesses go to the stage 2 design */
#define CTRL_WR_ENABLE      (1u << 16)

#define STS_ERR             (1u << 0)
#define STS_EOS             (1u << 1)
#define STS_FIFO_OVFL       (1u << 8)
#define STS_ACCESS          (1u << 24)  /* set while MCAP has no access to the configuration engine */

#define NOOP_WORD           0x20000000u
#define EOS_RETRIES         10
#define EOS_NOOPS           100
#define CHUNK_BYTES         (256 * 1024)

/* AXI-Lite (BAR0) registers of the example design. */
#define DNA_LS              0x1000
#define DNA_US              0x1008
#define DNA_MS              0x7000
#define DNA_READY           0x7008

/* DMA loop test targets on the XDMA AXI port (sqrl_fk_project.tcl address map). */
#define BRAM_ADDRESS        0x200000000ULL
#define BRAM_SIZE           (256 * 1024)
#define HBM0_ADDRESS        0x000000000ULL
#define HBM1_ADDRESS        0x100000000ULL

static HANDLE g_dev = INVALID_HANDLE_VALUE;
static SQRLFK_INFO g_info;
static unsigned char *g_dma;    /* DMA request or result header, then data */

static void fail(const char *what)
{
    DWORD err = GetLastError();
    char msg[256] = "";
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS, NULL, err, 0, msg, sizeof(msg), NULL);
    fprintf(stderr, "%s failed: error %lu %s", what, err, msg);
    if (msg[0] == 0)
        fprintf(stderr, "\n");
    exit(1);
}

static void dev_ioctl(DWORD code, void *in, DWORD inLength, void *out, DWORD outLength, const char *what)
{
    DWORD returned;
    if (!DeviceIoControl(g_dev, code, in, inLength, out, outLength, &returned, NULL))
        fail(what);
}

static ULONG cfg_read(ULONG offset)
{
    ULONG v = offset;
    dev_ioctl(IOCTL_SQRLFK_CFG_READ, &v, sizeof(v), &v, sizeof(v), "configuration read");
    return v;
}

static ULONG mcap_read(ULONG reg)
{
    return cfg_read(g_info.McapOffset + reg);
}

static void mcap_write(ULONG reg, ULONG value)
{
    SQRLFK_ACCESS a = { 0, reg, value };
    dev_ioctl(IOCTL_SQRLFK_MCAP_WRITE, &a, sizeof(a), NULL, 0, "MCAP register write");
}

static ULONG bar_read(ULONG bar, ULONG offset)
{
    SQRLFK_ACCESS a = { bar, offset, 0 };
    ULONG v;
    dev_ioctl(IOCTL_SQRLFK_BAR_READ, &a, sizeof(a), &v, sizeof(v), "BAR read");
    return v;
}

static void bar_write(ULONG bar, ULONG offset, ULONG value)
{
    SQRLFK_ACCESS a = { bar, offset, value };
    dev_ioctl(IOCTL_SQRLFK_BAR_WRITE, &a, sizeof(a), NULL, 0, "BAR write");
}

static void open_board(int index)
{
    wchar_t name[32];
    _snwprintf(name, 32, L"%ls%d", SQRLFK_DEVICE_NAME, index);
    g_dev = CreateFileW(name, GENERIC_READ | GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
    if (g_dev == INVALID_HANDLE_VALUE) {
        fprintf(stderr, "Cannot open %ls (error %lu). Is sqrlfk.sys installed for the board, and is this an "
                "Administrator prompt?\n", name, GetLastError());
        exit(1);
    }
    dev_ioctl(IOCTL_SQRLFK_GET_INFO, NULL, 0, &g_info, sizeof(g_info), "get info");
}

static void need_mcap(void)
{
    if (g_info.McapOffset == 0) {
        fprintf(stderr, "The board has no MCAP capability: the design is not a PCIe Tandem (stage 2 over PCIe) build.\n");
        exit(1);
    }
}

static void print_mcap(void)
{
    ULONG status = mcap_read(MCAP_STATUS), control = mcap_read(MCAP_CONTROL);
    printf("MCAP at configuration offset 0x%03lX: JTAG ID 0x%08lX, bitstream version 0x%08lX\n",
           g_info.McapOffset, mcap_read(MCAP_JTAG_ID), mcap_read(MCAP_BIT_VERSION));
    printf("  status  0x%08lX: EOS=%d ERR=%d FIFO_OVFL=%d ACCESS=%d\n", status, !!(status & STS_EOS),
           !!(status & STS_ERR), !!(status & STS_FIFO_OVFL), !!(status & STS_ACCESS));
    printf("  control 0x%08lX: ENABLE=%d REQ_ACCESS=%d WR_ENABLE=%d RESET=%d MOD_RESET=%d DESIGN_SWITCH=%d\n", control,
           !!(control & CTRL_ENABLE), !!(control & CTRL_REQ_ACCESS), !!(control & CTRL_WR_ENABLE),
           !!(control & CTRL_RESET), !!(control & CTRL_MOD_RESET), !!(control & CTRL_CFG_SWITCH));
}

static int cmd_info(void)
{
    ULONG i, command = cfg_read(4) & 0xFFFF;
    printf("sqrlfk.sys %lu.%lu, PCI %04lX:%04lX at bus %lu, device %lu, function %lu, memory decode %s\n",
           g_info.Version >> 16, g_info.Version & 0xFFFF, g_info.VendorDevice & 0xFFFF, g_info.VendorDevice >> 16,
           g_info.BusNumber, g_info.Address >> 16, g_info.Address & 0xFFFF, (command & 2) ? "on" : "off");
    for (i = 0; i < SQRLFK_MAX_BARS; i++)
        if (g_info.BarLength[i] != 0)
            printf("BAR%lu at 0x%llX, %lu KB\n", i, g_info.BarAddress[i], g_info.BarLength[i] / 1024);
    if (g_info.DmaBar != SQRLFK_NO_BAR) {
        ULONG h2c = bar_read(g_info.DmaBar, 0x0000), c2h = bar_read(g_info.DmaBar, 0x1000);
        printf("XDMA registers in BAR%lu: H2C0 0x%08lX, C2H0 0x%08lX%s; DMA buffer %lu KB, bus master %s\n",
               g_info.DmaBar, h2c, c2h, (h2c >> 16) == 0x1FC0 ? "" : " (no engines: stage 2 not loaded)",
               g_info.DmaBufferSize / 1024, (command & 4) ? "on" : "off");
    }
    if (g_info.McapOffset != 0)
        print_mcap();
    else
        printf("No MCAP capability (not a PCIe Tandem stage 2 over PCIe build)\n");
    return 0;
}

/* Reads a .bit (header skipped) or .bin file; returns the configuration words in bitstream order. */
static ULONG *read_bitstream(const char *path, ULONG *count)
{
    FILE *f = fopen(path, "rb");
    unsigned char *data, *p;
    long size;
    ULONG *words, n, i;

    if (f == NULL) {
        perror(path);
        exit(1);
    }
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, 0, SEEK_SET);
    data = malloc(size > 0 ? size : 1);
    if (data == NULL || fread(data, 1, size, f) != (size_t)size) {
        fprintf(stderr, "Cannot read %s\n", path);
        exit(1);
    }
    fclose(f);
    p = data;
    /* .bit: 00 09 <9 bytes> 00 01, then fields 'a'-'d' (16-bit length) and 'e' (32-bit length, bitstream). */
    if (size > 13 && data[0] == 0x00 && data[1] == 0x09) {
        long pos = 13;
        for (;;) {
            if (pos + 5 > size) {
                fprintf(stderr, "%s: no bitstream data field in the .bit header\n", path);
                exit(1);
            }
            if (data[pos] == 'e') {
                ULONG length = (ULONG)data[pos + 1] << 24 | data[pos + 2] << 16 | data[pos + 3] << 8 | data[pos + 4];
                pos += 5;
                if (length > (ULONG)(size - pos)) {
                    fprintf(stderr, "%s: truncated .bit file\n", path);
                    exit(1);
                }
                p = data + pos;
                size = length;
                break;
            }
            pos += 3 + (data[pos + 1] << 8 | data[pos + 2]);
        }
    }
    if (size < 64 || (size & 3)) {
        fprintf(stderr, "%s: %ld bytes is not a bitstream\n", path, size);
        exit(1);
    }
    /* The configuration engine takes big-endian words, as stored in the file. */
    n = (ULONG)size / 4;
    words = malloc(n * sizeof(ULONG));
    if (words == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    for (i = 0; i < n; i++)
        words[i] = (ULONG)p[4 * i] << 24 | p[4 * i + 1] << 16 | p[4 * i + 2] << 8 | p[4 * i + 3];
    free(data);
    *count = n;
    return words;
}

static void send_words(const ULONG *words, ULONG count, BOOL progress)
{
    ULONG done = 0, chunk;
    while (done < count) {
        chunk = count - done;
        if (chunk > CHUNK_BYTES / 4)
            chunk = CHUNK_BYTES / 4;
        dev_ioctl(IOCTL_SQRLFK_MCAP_DATA, (void *)(words + done), chunk * 4, NULL, 0, "MCAP data write");
        done += chunk;
        if (progress) {
            printf("\r  %3lu%%", (ULONG)((ULONGLONG)done * 100 / count));
            fflush(stdout);
        }
    }
    if (progress)
        printf("\n");
}

static int cmd_load(const char *path, BOOL force)
{
    ULONG count, status, control, restore, i;
    ULONG noops[EOS_NOOPS];
    ULONG *words;
    LARGE_INTEGER t0, t1, freq;
    DWORD start;

    need_mcap();
    print_mcap();
    restore = mcap_read(MCAP_CONTROL);
    if ((restore & CTRL_CFG_SWITCH) && !force) {
        printf("The design switch is on: stage 2 is already loaded. A stage 2 must be loaded only once after stage 1 "
               "(use -f to load anyway).\n");
        return 0;
    }
    words = read_bitstream(path, &count);
    printf("Loading %s: %lu bytes\n", path, count * 4);

    /* Request access to the configuration engine. */
    status = mcap_read(MCAP_STATUS);
    if (status & STS_ACCESS) {
        mcap_write(MCAP_CONTROL, restore | CTRL_ENABLE | CTRL_REQ_ACCESS);
        start = GetTickCount();
        while ((mcap_read(MCAP_STATUS) & STS_ACCESS) && GetTickCount() - start < 2000)
            ;
        if (mcap_read(MCAP_STATUS) & STS_ACCESS) {
            mcap_write(MCAP_CONTROL, restore);
            fprintf(stderr, "MCAP did not get access to the configuration engine\n");
            return 1;
        }
    }
    control = mcap_read(MCAP_CONTROL);
    control |= CTRL_WR_ENABLE | CTRL_ENABLE | CTRL_REQ_ACCESS;
    control &= ~(CTRL_RESET | CTRL_MOD_RESET | CTRL_RD_ENABLE | CTRL_CFG_SWITCH);
    mcap_write(MCAP_CONTROL, control);

    QueryPerformanceFrequency(&freq);
    QueryPerformanceCounter(&t0);
    send_words(words, count, TRUE);
    free(words);

    /* Wait for end of startup, feeding NOOPs like Xilinx's driver does. */
    for (i = 0; i < EOS_NOOPS; i++)
        noops[i] = NOOP_WORD;
    status = mcap_read(MCAP_STATUS);
    for (i = 0; !(status & STS_EOS) && i < EOS_RETRIES; i++) {
        Sleep(20);
        send_words(noops, EOS_NOOPS, FALSE);
        status = mcap_read(MCAP_STATUS);
    }
    QueryPerformanceCounter(&t1);
    if (!(status & STS_EOS) || (status & (STS_ERR | STS_FIFO_OVFL))) {
        fprintf(stderr, "Stage 2 failed: MCAP status 0x%08lX (EOS=%d ERR=%d FIFO_OVFL=%d). Resetting MCAP.\n", status,
                !!(status & STS_EOS), !!(status & STS_ERR), !!(status & STS_FIFO_OVFL));
        mcap_write(MCAP_CONTROL, restore | CTRL_ENABLE | CTRL_REQ_ACCESS | CTRL_RESET | CTRL_MOD_RESET);
        Sleep(1);
        mcap_write(MCAP_CONTROL, restore);
        return 1;
    }
    /* Release the configuration engine and switch BAR accesses to the stage 2 design. */
    mcap_write(MCAP_CONTROL, restore | CTRL_CFG_SWITCH);
    printf("Stage 2 loaded in %.1f s: end of startup (MCAP status 0x%08lX)\n",
           (double)(t1.QuadPart - t0.QuadPart) / freq.QuadPart, status);
    printf("After the release (EOS reads 0 once MCAP has released the configuration engine):\n");
    print_mcap();
    return 0;
}

static int cmd_dna(void)
{
    ULONG ls, us, ms, ready;
    if (g_info.BarLength[0] == 0) {
        fprintf(stderr, "BAR0 is not mapped\n");
        return 1;
    }
    ls = bar_read(0, DNA_LS);
    us = bar_read(0, DNA_US);
    ms = bar_read(0, DNA_MS);
    ready = bar_read(0, DNA_READY);
    if (ls == 0xFFFFFFFF && us == 0xFFFFFFFF && ms == 0xFFFFFFFF && ready == 0xFFFFFFFF) {
        printf("BAR0 reads all ones: stage 2 is not loaded (or the design switch is off)\n");
        return 1;
    }
    printf("DNA (design dna_reader): %08lX%08lX%08lX ready=%lu\n", ms, us, ls, ready & 1);
    return 0;
}

static ULONGLONG parse_number64(const char *s)
{
    char *end;
    unsigned long long v = strtoull(s, &end, 0);
    if (*s == 0 || *end != 0) {
        fprintf(stderr, "Not a number: %s\n", s);
        exit(1);
    }
    return v;
}

static ULONG parse_number(const char *s)
{
    ULONGLONG v = parse_number64(s);
    if (v > 0xFFFFFFFFULL) {
        fprintf(stderr, "Number too large: %s\n", s);
        exit(1);
    }
    return (ULONG)v;
}

/* One XDMA transfer between <data> and the card's AXI address <card>; FALSE with the reason printed on failure. */
static BOOL dma_transfer(BOOL c2h, ULONGLONG card, void *data, ULONG length, SQRLFK_DMA_RESULT *r)
{
    static const char *const errors[] = { "", "timeout", "engine error", "no XDMA engine (stage 2 not loaded?)" };
    SQRLFK_DMA *q = (SQRLFK_DMA *)g_dma;
    DWORD returned;

    q->CardAddress = card;
    q->Length = length;
    q->Channel = 0;
    if (!c2h)
        memcpy(g_dma + sizeof(SQRLFK_DMA), data, length);
    if (!DeviceIoControl(g_dev, c2h ? IOCTL_SQRLFK_DMA_READ : IOCTL_SQRLFK_DMA_WRITE, g_dma,
                         sizeof(SQRLFK_DMA) + (c2h ? 0 : length), g_dma, sizeof(SQRLFK_DMA_RESULT) + (c2h ? length : 0),
                         &returned, NULL))
        fail(c2h ? "DMA read" : "DMA write");
    *r = *(SQRLFK_DMA_RESULT *)g_dma;
    if (r->Error != SQRLFK_DMA_OK) {
        printf("%s DMA at 0x%llX failed: %s, engine status 0x%08lX\n", c2h ? "C2H" : "H2C", card,
               r->Error < 4 ? errors[r->Error] : "?", r->EngineStatus);
        return FALSE;
    }
    if (c2h)
        memcpy(data, g_dma + sizeof(SQRLFK_DMA_RESULT), length);
    return TRUE;
}

/* Writes a pseudo-random pattern to <card>, reads it back and compares, <iterations> times. */
static int loop_target(const char *name, ULONGLONG card, ULONG length, int iterations)
{
    ULONG *out = malloc(length), *in = malloc(length), n = length / 4, i, bad;
    ULONGLONG h2c = 0, c2h = 0;
    SQRLFK_DMA_RESULT r;
    double total = (double)length * iterations;
    int it;

    if (out == NULL || in == NULL) {
        fprintf(stderr, "Out of memory\n");
        exit(1);
    }
    for (it = 0; it < iterations; it++) {
        ULONG s = ((ULONG)(card >> 12) ^ (ULONG)(it + 1) * 0x9E3779B9u) | 1;
        for (i = 0; i < n; i++) {
            s ^= s << 13;
            s ^= s >> 17;
            s ^= s << 5;
            out[i] = s;
        }
        memset(in, 0, length);
        if (!dma_transfer(FALSE, card, out, length, &r))
            goto failed;
        h2c += r.Nanoseconds;
        if (!dma_transfer(TRUE, card, in, length, &r))
            goto failed;
        c2h += r.Nanoseconds;
        for (i = 0, bad = 0; i < n; i++)
            if (in[i] != out[i] && bad++ == 0)
                printf("%s: data error at 0x%llX: wrote 0x%08lX, read 0x%08lX\n", name, card + 4ULL * i, out[i], in[i]);
        if (bad) {
            printf("%s: %lu of %lu words differ (iteration %d)\n", name, bad, n, it + 1);
            goto failed;
        }
    }
    printf("%-12s 0x%09llX %5lu KB x %d: H2C %5.0f MB/s, C2H %5.0f MB/s, data OK\n", name, card, length / 1024,
           iterations, total / h2c * 1000, total / c2h * 1000);
    free(out);
    free(in);
    return 0;
failed:
    printf("%-12s 0x%09llX FAILED\n", name, card);
    free(out);
    free(in);
    return 1;
}

static int cmd_loop(int argc, char **argv, int i, int iterations)
{
    ULONG size = g_info.DmaBufferSize, length;
    int failures = 0;

    if (g_info.DmaBar == SQRLFK_NO_BAR || size == 0) {
        fprintf(stderr, "No XDMA DMA BAR or no DMA buffer in the driver\n");
        return 1;
    }
    g_dma = malloc(sizeof(SQRLFK_DMA_RESULT) + size);
    if (g_dma == NULL) {
        fprintf(stderr, "Out of memory\n");
        return 1;
    }
    if (i < argc) {
        ULONGLONG card = parse_number64(argv[i]);
        length = i + 1 < argc ? parse_number(argv[i + 1]) : size;
        if (length == 0 || (length & 3) || length > size) {
            fprintf(stderr, "Length must be a multiple of 4 from 4 to %lu bytes\n", size);
            return 1;
        }
        return loop_target("AXI", card, length, iterations);
    }
    printf("XDMA loop test, channel 0, DMA buffer %lu KB, %d iterations per target\n", size / 1024, iterations);
    failures += loop_target("BRAM", BRAM_ADDRESS, size < BRAM_SIZE ? size : BRAM_SIZE, iterations);
    failures += loop_target("HBM stack 0", HBM0_ADDRESS, size, iterations);
    failures += loop_target("HBM stack 1", HBM1_ADDRESS, size, iterations);
    return failures ? 1 : 0;
}

static __declspec(noreturn) void usage(void)
{
    fprintf(stderr,
            "Usage: sqrl_fk_mcap [-d board] [-b bar] [-f] [-n iterations] <command>\n"
            "  info                 board, BARs, XDMA and MCAP registers\n"
            "  load <stage2.bit>    load a PCIe Tandem stage 2 bitstream (.bit or .bin) through MCAP\n"
            "  dna                  read the design's device DNA over BAR0\n"
            "  read <offset>        read a 32-bit BAR register\n"
            "  write <offset> <value>\n"
            "  loop [<address> [<bytes>]]\n"
            "                       XDMA loop test (H2C write, C2H read back, compare); without an address:\n"
            "                       BRAM 0x200000000, HBM stack 0 0x0 and stack 1 0x100000000\n");
    exit(1);
}

int main(int argc, char **argv)
{
    int board = 0, iterations = 10, i = 1;
    ULONG bar = 0;
    BOOL force = FALSE;
    const char *cmd;

    while (i < argc && argv[i][0] == '-') {
        if (strcmp(argv[i], "-d") == 0 && i + 1 < argc)
            board = (int)parse_number(argv[++i]);
        else if (strcmp(argv[i], "-b") == 0 && i + 1 < argc)
            bar = parse_number(argv[++i]);
        else if (strcmp(argv[i], "-n") == 0 && i + 1 < argc)
            iterations = (int)parse_number(argv[++i]);
        else if (strcmp(argv[i], "-f") == 0)
            force = TRUE;
        else
            usage();
        i++;
    }
    if (i >= argc)
        usage();
    cmd = argv[i++];
    open_board(board);
    if (strcmp(cmd, "info") == 0)
        return cmd_info();
    if (strcmp(cmd, "load") == 0 && i < argc)
        return cmd_load(argv[i], force);
    if (strcmp(cmd, "dna") == 0)
        return cmd_dna();
    if (strcmp(cmd, "loop") == 0)
        return cmd_loop(argc, argv, i, iterations < 1 ? 1 : iterations);
    if (strcmp(cmd, "read") == 0 && i < argc) {
        ULONG offset = parse_number(argv[i]);
        printf("BAR%lu 0x%05lX = 0x%08lX\n", bar, offset, bar_read(bar, offset));
        return 0;
    }
    if (strcmp(cmd, "write") == 0 && i + 1 < argc) {
        bar_write(bar, parse_number(argv[i]), parse_number(argv[i + 1]));
        return 0;
    }
    usage();
}
