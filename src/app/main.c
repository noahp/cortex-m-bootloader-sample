#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "stm32f407xx.h"

// Two non-initialized variables, used to demonstrate keeping information
// through chip reset.
#define RESET_MAGIC 0xDEADBEEF
// magic value used to check if the variables are initialized
__attribute__((section(".noinit"), used)) uint32_t reset_count_magic;
// reset counter, incremented on every warm reset
__attribute__((section(".noinit"), used)) uint32_t reset_count;

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
    (void *)(&__stack),  // initial stack pointer
    Reset_Handler,
    0,
    HardFault_Handler,
};

int main(void) {
  initialise_monitor_handles();

  // line buffering on stdout
  setvbuf(stdout, NULL, _IOLBF, 0);

  printf("Hello from Application!\n");

  if (reset_count_magic != RESET_MAGIC) {
    reset_count_magic = RESET_MAGIC;
    reset_count = 0;

    printf("First reset!\n");
  }

  printf("Reset count: %" PRIu32 "\n", ++reset_count);

  volatile uint32_t countdown = 48*1000*1000;
  while (countdown--) {
    __asm__("nop");
  };

  NVIC_SystemReset();

  return 0;
}
