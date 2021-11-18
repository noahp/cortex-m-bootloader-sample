#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
  // line buffering on stdout
  setvbuf(stdout, NULL, _IOLBF, 0);

  printf("Hello from Bootloader!\n");

  extern uint32_t mailbox[4];
  mailbox[0] = 0x12345678;

  extern uint32_t __application_start[2];

  // set the vector table base address for application
  uint32_t *vector_table = (uint32_t *)__application_start;
  uint32_t *vtor = (uint32_t *)0xE000ED08;
  *vtor = ((uint32_t)vector_table & 0xFFFFFFF8UL);

  // set application stack pointer and jump to application
  __asm__("msr msp, %0\n" : : "r"(vector_table[0]));

  // NOLINTNEXTLINE(performance-no-int-to-ptr)
  ((void (*)(void))(((uint32_t *)vector_table)[1]))();

  while (1) {
  };

  return 0;
}
