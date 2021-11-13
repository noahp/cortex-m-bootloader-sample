#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

extern void initialise_monitor_handles(void);

int main(void);

// Following symbols are defined by the linker.
// Start address for the initialization values of the .data section.
extern uint32_t __etext;
// Start address for the .data section
extern uint32_t __data_start__;
// End address for the .data section
extern uint32_t __data_end__;
// Start address for the .bss section
extern uint32_t __bss_start__;
// End address for the .bss section
extern uint32_t __bss_end__;
// End address for stack
extern uint32_t __stack;

// Prevent inlining to avoid persisting any stack allocations
__attribute__((noinline)) static void prv_cinit(void) {
  // Initialize data and bss
  // Copy the data segment initializers from flash to SRAM
  for (uint32_t *dst = &__data_start__, *src = &__etext; dst < &__data_end__;) {
    *(dst++) = *(src++);
  }

  // Zero fill the bss segment.
  for (uint32_t *dst = &__bss_start__;
       (uintptr_t)dst < (uintptr_t)&__bss_end__;) {
    *(dst++) = 0;
  }
}

__attribute__((noreturn)) void Reset_Handler(void) {
  prv_cinit();

  // Call the application's entry point.
  (void)main();

  // shouldn't return
  while (1) {
  };
}

__attribute__((weak)) void HardFault_Handler(void) {
  __asm__("bkpt 92");
  while (1) {
  };
}

// A minimal vector table for a Cortex M.
__attribute__((section(".isr_vector"))) void (*const g_pfnVectors[])(void) = {
    (void *)(&__stack), // initial stack pointer
    Reset_Handler,
    0,
    HardFault_Handler,
};

int main(void) {
  initialise_monitor_handles();

  // line buffering on stdout
  setvbuf(stdout, NULL, _IOLBF, 0);

  printf("Hello from Bootloader!\n");

  extern uint32_t mailbox[4];
  mailbox[0] = 0x12345678;

  extern uint32_t __application_start[2];

  // set the vector table base address for application
  uint32_t *vector_table = (uint32_t *)__application_start;
  uint32_t *vtor = (uint32_t *)0xE000ED08;
  *vtor = ((uint32_t)vector_table & 0xFFFFFFF8);

  // set application stack pointer and jump to application
  __asm__("msr msp, %0\n" : : "r"(vector_table[0]));

  ((void (*)(void))(((uint32_t *)vector_table)[1]))();

  while (1) {
  };

  return 0;
}
