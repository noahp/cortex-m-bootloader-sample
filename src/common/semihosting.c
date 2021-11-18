// Semihosting functions. Derived from newlib sources (see
// initialise_monitor_handles).

#include "semihosting.h"

#include <errno.h>
#include <stdint.h>
#include <stdio.h>

static int stdout_handle = -1;

#define AngelSWI_Reason_Open 0x01
#define AngelSWI_Reason_Write 0x05

#define AngelSWIInsn "bkpt"

#define AngelSWI 0xAB

int32_t _write(int32_t file, char *ptr, int32_t len) {
  return semihosting_write(file, ptr, len);
}

static inline int do_AngelSWI(int reason, void *arg) {
  int value;
  __asm__ volatile(
      "mov r0, %1\n\t"
      "mov r1, %2\n\t"
      "" AngelSWIInsn
      " %a3\n\t"
      "mov %0, r0"
      : "=r"(value)                          /* Outputs */
      : "r"(reason), "r"(arg), "i"(AngelSWI) /* Inputs */
      : "r0", "r1", "r2", "r3", "ip", "lr", "memory", "cc"
      /* Clobbers r0 and r1, and lr if in supervisor mode */);
  /* Accordingly to page 13-77 of ARM DUI 0040D other registers
     can also be clobbered.  Some memory positions may also be
     changed by a system call, so they should not be kept in
     registers. Note: we are assuming the manual is right and
     Angel is respecting the APCS.  */
  return value;
}

int semihosting_write(int file, char *ptr, int len) {
  if (file == 1) {  // stdout
    if (stdout_handle == -1) {
      semihosting_init();
    }
    int block[3] = {stdout_handle /*file*/, (int)ptr, len};

    // Writes to stderr will hang forever if there is no debugger attached.
    // stderr is piped directly to the gdb shell. For more information, see
    // "ARM Compiler Software Development Guide", subsection "Semihosting".
    return do_AngelSWI(AngelSWI_Reason_Write, block);
  }
  return -EIO;
}

void semihosting_init(void) {
  int volatile block[3];

  // open stdout
  block[0] = (int)":tt";
  block[2] = 3; /* length of filename */
  block[1] = 4; /* mode "w" */
  stdout_handle = do_AngelSWI(AngelSWI_Reason_Open, (void *)block);
}
