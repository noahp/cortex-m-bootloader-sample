MEMORY
{
  APP_FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 1M
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 128K - 0x100
  NOINIT (rwx) : ORIGIN = 0x20000000 + 128K - 0x100, LENGTH = 0x100
}

/* Entry point for our program */
ENTRY(Reset_Handler)

/* The start of the application region, used by the bootloader */
__application_start = ORIGIN(APP_FLASH);

SECTIONS
{
    .text :
    {
        KEEP(*(.isr_vector))
        *(.text*)
        KEEP(*(.init))
        KEEP(*(.fini))
        *(.rodata*)
    } > APP_FLASH

    /* Location counter can end up 2byte aligned with narrow Thumb code but
       __etext is assumed by startup code to be the LMA of a section in RAM
       which must be 4byte aligned */
    __etext = ALIGN (4);

    .data : AT (__etext)
    {
        __data_start__ = .;
        *(.data*)

        . = ALIGN(4);

        /* All data end */
        __data_end__ = .;

    } > RAM

    .bss :
    {
        . = ALIGN(4);
        __bss_start__ = .;
        *(.bss*)
        . = ALIGN(4);
        __bss_end__ = .;
    } > RAM

     /* Global data not cleared after reset.  */
    .noinit (NOLOAD): {
        KEEP(*(*.noinit*))
    } > NOINIT

    .heap (COPY):
    {
        __end__ = .;
        PROVIDE(end = .);
        *(.heap*)
        __HeapLimit = .;
    } > RAM

    /* .stack_dummy section doesn't contains any symbols. It is only
     * used for linker to calculate size of stack sections, and assign
     * values to stack symbols later */
    .stack_dummy (COPY):
    {
        *(.stack*)
    } > RAM

    /* Set stack top to end of RAM, and stack limit move down by
     * size of stack_dummy section */
    __StackTop = ORIGIN(RAM) + LENGTH(RAM);
    __StackLimit = __StackTop - SIZEOF(.stack_dummy);
    PROVIDE(__stack = __StackTop);

    /* Check if data + heap + stack exceeds RAM limit */
    ASSERT(__StackLimit >= __HeapLimit, "region RAM overflowed with stack")
}
