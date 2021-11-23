# cortex-m-bootloader-sample

Based on https://github.com/noahp/pico-c-cortex-m , this project shows a simple
bootloader+application configuration for an ARM Cortex-M.

The bootloader and app each have their own linker script.

Also demonstrates how to keep a "`.noinit`" region in RAM that won't be
overwritten on program initialization, and can be used to preserve data through
a warm reboot or for passing information between bootloader and application.

### `.noinit` region

A region of RAM is reserved for symbols placed into any `.noinit*` section. In
this example the `NOINIT` region is the top 0x100 bytes of RAM.

## How to run it

To build + run it on an STM32F4 Discovery board:

```bash
# necessary tools (ubuntu, other systems may be different)
❯ sudo apt install openocd gcc-arm-none-eabi

# start openocd in one terminal
❯ make debug

# in another terminal, run this command to build and start gdb
❯ make gdb-app

# 'continue' in gdb, you should see 'Hello from Bootloader!' etc in openocd
```
