
#include <stdint.h>

// marked 'volatile' to ensure the compiler doesn't optimize away the STR's to
// these addresses
__attribute__((section(".noinit"))) volatile uint32_t mailbox[4];
