# Windows driver: PCIe Tandem stage 2 over MCAP

`sqrlfk.sys` is a small KMDF driver for the example design (PCI vendor 1E24, device 1533) on Windows 10 (1709 and
later) and 11, 64-bit. `sqrl_fk_mcap.exe` uses it to:

- load a **PCIe Tandem stage 2** bitstream through the PCIe block's MCAP (Media Configuration Access Port),
- read and write 32-bit registers in the BARs (BAR0 is the XDMA AXI-Lite master: DNA, I2C, system monitor),
- read the design's device DNA,
- run XDMA transfers and the **XDMA loop test** (host to card with H2C, card to host with C2H, compare) on the
  on-chip BRAM and both HBM stacks.

The full procedure (Vivado build, flash, driver build, install and test) is in
[docs/Build_and_Test.md](../../docs/Build_and_Test.md).

## Which Tandem mode needs it

| `PCIeTandem` in `sqrl_fk_project.tcl` | Flash holds | Stage 2 comes from | Driver |
| --- | --- | --- | --- |
| `PROM` | stage 1 + stage 2 | the flash | optional (register access only, no MCAP) |
| `PCIe` | stage 1 only | the host, through MCAP | required: `sqrl_fk_mcap load` after every power-on |

On UltraScale+ the two cannot be mixed in one image: Tandem PROM has no MCAP stage 2 path, and in Tandem PCIe stage 2
never comes from the flash (AMD PG213, "Tandem Configuration"). A stage 2 must be delivered exactly once after its own
stage 1, and only the stage 2 from the same build works. Loading a different stage 2 later needs the Tandem PCIe with
Field Updates (Dynamic Function eXchange) flow, which this project does not use.

## Build

`build.bat` builds with the [Enterprise WDK](https://learn.microsoft.com/en-us/windows-hardware/drivers/download-the-wdk)
(EWDK, a single ISO with the Visual Studio Build Tools, the Windows SDK and the WDK; tested with build 28000.2526,
MSVC 14.50). Mount the ISO (double-click it in Explorer); `build.bat` finds it, or set `EWDK` to its drive or folder.

1. `sqrlfk.vcxproj` (MSBuild, KMDF 1.15, warning level 4 as errors) builds `sqrlfk.sys`; stampinf fills in DriverVer
   and the KMDF version in `sqrlfk.inf`.
2. `cl` builds `sqrl_fk_mcap.exe`.
3. `testcert.ps1` creates the code signing certificate `CN=SQRL FK Test Driver` in the current user's certificate store
   the first time; `signtool` signs `sqrlfk.sys`, `inf2cat` makes `sqrlfk.cat` (Windows 10 x64), which is signed too.
4. `infverif /w` checks the INF against the Windows Driver rules.

The result is the driver package in `package\`: `sqrlfk.sys`, `sqrlfk.inf`, `sqrlfk.cat`, `sqrlfk.cer`, `sqrlfk.pdb`
(symbols for WinDbg), `sqrl_fk_mcap.exe`, `install.bat`/`install.ps1`. `build.bat analyze` also runs the compiler's
static analysis (`/analyze` with the WDK driver rules); the EWDK's separate MSBuild Code Analysis task fails to load
its rule set, so it is not used.

## Install (test signing)

Windows 10/11 x64 loads only signed kernel drivers. This package is test-signed, which Windows accepts only in test
signing mode:

1. Secure Boot must be off. As administrator run `bcdedit /set testsigning on` and restart Windows ("Test Mode" shows
   on the desktop).
2. Run `package\install.bat`. It asks for administrator rights, then Windows asks whether to install a driver from an
   unverified publisher: choose to install it. The test certificate is not added to any trusted store.
3. Device Manager shows "SQRL Forest Kitten FK33/FK35" under System devices.

`package\install.bat /uninstall` removes the driver package. For other PCs without test signing, the package has to
be signed through Microsoft's attestation signing (Partner Center, EV certificate).

## Use

In an administrator prompt (the device can be opened only by Administrators and SYSTEM):

```bat
sqrl_fk_mcap info
sqrl_fk_mcap load SQRL_FK35\SQRL_FK35.runs\impl_1\bd_wrapper_tandem2.bit
sqrl_fk_mcap dna
sqrl_fk_mcap loop
sqrl_fk_mcap read 0x7008
```

- `info`: PCI location, mapped BARs, XDMA engine identifiers, DMA buffer size, MCAP status and control registers.
- `load <file>`: stage 2 as `.bit` or `.bin`. It follows Xilinx's MCAP sequence (XVSEC driver): request access,
  enable writes, stream the bitstream words, wait for end of startup (EOS), then set the design switch so BAR accesses
  reach the stage 2 design. It does nothing if the design switch is already on (`-f` loads anyway). About 4.5 million
  words for the FK35, written one configuration write at a time: 11.4 s. After the release the MCAP status reads
  `EOS=0` again; the tool reports the end of startup it saw before the release.
- `dna`: DNA[95:0] from BAR0 0x7000/0x1008/0x1000 and the ready bit 0x7008. All ones means stage 2 is not running.
- `loop [<address> [<bytes>]]`: XDMA loop test. Without an address it tests the BRAM (0x2_0000_0000, 256 KB) and
  HBM stacks 0 (0x0) and 1 (0x1_0000_0000) with the whole DMA buffer, 10 times each (`-n <count>`), and prints the
  H2C and C2H bandwidth of the DMA engines (measured in the driver, without the copies in Windows). FK35 in a Gen4 x4
  slot: about 7.1 GB/s H2C and 6.9 GB/s C2H for 4 MB transfers to HBM.
- `read <offset>` / `write <offset> <value>`: BAR0 registers; `-b <n>` selects another BAR, `-d <n>` another board.

A Tandem PCIe board stays at stage 1 (enumerated, BARs not answering) until `load` runs, so run it after every
power-on, for example from a Task Scheduler task. `scripts\sqrl_fk_pcie_test.bat` runs `info`, `load`, `dna` and
`loop` in one go with the paths set at its top, and logs the output to `%TEMP%\sqrl_fk_pcie_test.log`.

## Notes

- Requests go through one sequential KMDF queue at PASSIVE_LEVEL; the framework handles Plug and Play and power and
  stops the queue before the hardware is released.
- DMA: a KMDF DMA enabler with a common buffer (4 MB, less if contiguous memory is short); data is copied through it.
  Each request is one XDMA descriptor on channel 0, started and polled by the driver; the XDMA interrupts stay
  disabled (the driver has no interrupt handler). It turns on bus mastering for the board if Windows has not.
- Only one driver can own the device: the Xilinx XDMA driver cannot be installed at the same time.
- Sleep and hibernate turn the slot off, which unconfigures the FPGA.
- MCAP writes are limited to the MCAP control and write data registers; configuration reads to the first 4 KB.
