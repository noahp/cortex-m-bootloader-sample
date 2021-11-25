#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "stm32f407xx.h"

// Two non-initialized variables, used to demonstrate keeping information
// through chip reset. Marked 'volatile' to ensure the compiler doesn't optimize
// away the STR's to these addresses
#define RESET_MAGIC 0xDEADBEEF
// magic value used to check if the variables are initialized
__attribute__((section(".noinit"))) volatile uint32_t reset_count_magic;
// reset counter, incremented on every warm reset
__attribute__((section(".noinit"))) volatile uint32_t reset_count;

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
  // __ARM_FP is defined by the compiler if -mfloat-abi=hard is set
#if defined(__ARM_FP)
  // enable floating-point access; some instructions emitted at -O3 will make
  // use of the FP co-processor, eg vldr.64
#define CPACR (*(volatile uint32_t *)0xE000ED88)
  CPACR |= ((3UL << 10 * 2) | /* set CP10 Full Access */
            (3UL << 11 * 2)); /* set CP11 Full Access */
#endif
  // specific to stm32f4xx, enable HSI clock
  /* Set HSION bit */
  RCC->CR |= (uint32_t)0x00000001;

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

static void delay_a_few_seconds(void) {
  // chip defaults to the High Speed Internal Clock (HSI) at 16MHz
  volatile uint32_t countdown = 16 * 1000 * 1000;
  // this delay loop is (very roughly) 4 cycles per iteration
  countdown /= 4;
  while (countdown--) {
    __asm__("nop");
  };
}

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

  // delay for a few seconds, then reset the chip
  delay_a_few_seconds();

  NVIC_SystemReset();

  return 0;
}
