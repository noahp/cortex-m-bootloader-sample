#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
  // line buffering on stdout
  setvbuf(stdout, NULL, _IOLBF, 0);

  printf("Hello from Application!\n");

  extern uint32_t mailbox[4];
  printf("mailbox was: 0x%08" PRIx32 "\n", mailbox[0]);

  while (1) {
  };

  return 0;
}
