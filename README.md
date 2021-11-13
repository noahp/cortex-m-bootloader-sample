# cortex-m-bootloader-sample

Based on https://github.com/noahp/pico-c-cortex-m , this project shows a simple
bootloader+application configuration for an ARM Cortex-M.

The bootloader and app share a linker script, which is run through the C
preprocessor to select placing code/read-only data into the bootloader or
application region.

Also demonstrates how to keep a "`.noinit`" region in RAM that won't be
overwritten on program initialization, and can be used to preserve data through
a warm reboot or for passing information between bootloader and application.
