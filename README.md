# cortex-m-bootloader-sample

Based on https://github.com/noahp/pico-c-cortex-m , this project shows a simple
bootloader+application configuration for an ARM Cortex-M.

The bootloader and app share a linker script, which is run through the C
preprocessor to select placing code/read-only data into the bootloader or
application region.

Also demonstrates how to keep a "`.noinit`" region in RAM that won't be
overwritten on program initialization, and can be used to preserve data through
a warm reboot or for passing information between bootloader and application.

## Memory map

This is the device memory map, containing the bootloader and application.

Addresses are specific to the STM32F407VG (general idea applies to other SOCs
though).

```plaintext
FLASH:
 ┌───────────────────┐08000000
 │.bootloader        │
 ├───────────────────┤08004000
 │.text (application)│
 ├───────────────────┤080059f4 (end of .text)
 │.note.gnu.build-id │
 └───────────────────┘

RAM:
 ┌───────────────────┐20000000
 │.data              │
 ├───────────────────┤20000078
 │.bss               │
 ├───────────────────┤2001b000
 │.noinit            │
 └───────────────────┘
```

### Linker script

The application and bootloader share a linker script, but are linked to run from
different flash regions.

The correct output region in flash for `.text` and other read-only sections is
specified by the following hack:

1. for example, for linking the application, first generate an `app.ld` by
   running the [`src/common/stm32f407.ld`](src/common/stm32f407.ld) through the
   C preprocessor, replacing the `FLASH__` strings with `APPLICATION_FLASH`
   (could also be done with eg `sed`). _This is inspired from how zephyr
   composes linker scripts_
2. link the application using the `app.ld` script, which will place everything
   into the correct `APPLICATION_FLASH` region.

RAM region selection is the same between bootloader and application; this means
that the memory map for both programs is in a single file, and the `.noinit`
section definition is shared.

### Application and bootloader linking

The application contains the bootloader in a special output section placed at
the start of flash filling exactly 1 flash sector, which means on chip reset,
the bootloader runs first.

The application ELF is produced by the following steps (see
[`Makefile`](Makefile) for specifics):

1. bootloader executable is linked, with the `FLASH__` regions set to
   `BOOTLOADER_FLASH`.
2. bootloader ELF is converted to raw binary image `bootloader.bin`
3. `bootloader.bin` is converted to an object file, `bootloader.o`, with raw
   image data placed in a section `.bootloader`.
4. application executable is linked, including the `bootloader.o` file, with the
   `.bootloader` output section placed at the `BOOTLOADER_FLASH` region (start
   of flash), and `FLASH__` regions set to `APPLICATION_FLASH`.

### `.noinit` region

A region of RAM is reserved for symbols placed into any `.noinit*` section. In
this example the `NOINIT` region is the top 0x100 bytes of RAM.

Since the bootloader

## How to run it

To build + run it on an STM32F4 Discovery board:

```bash
# necessary tools (ubuntu, other systems may be different)
❯ sudo apt install openocd gcc-arm-none-eabi

# start openocd in one terminal
❯ make debug

# in another terminal, run this command to build and start gdb
❯ make gdb

# 'continue' in gdb, you should see 'Hello from Bootloader!' etc in openocd
```
