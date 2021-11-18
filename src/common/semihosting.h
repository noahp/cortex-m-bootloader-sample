#pragma once

// Semihosting functions. Derived from newlib sources (see
// initialise_monitor_handles).

// this can be put into a _write implementation to handle output from stdio, eg:
// int _write(int file, char *ptr, int len) {
//   return semihosting_write(file, ptr, len);
// }
int semihosting_write(int file, char *ptr, int len);

// init, should be called once on system startup to load stdio handles from the
// debug monitor
void semihosting_init(void);
