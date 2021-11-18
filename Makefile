# disable echoing rule commands, run make with --trace to see them
.SILENT:

ARM_CC ?= arm-none-eabi-gcc
# if cc isn't set by the user, set it to ARM_CC
ifeq ($(origin CC),default)
CC := $(ARM_CC)
endif

GDB ?= arm-none-eabi-gdb-py

# use ccache if available
CCACHE := $(shell command -v ccache 2> /dev/null)
ifdef CCACHE
CC := ccache $(CC)
endif

RM = rm -rf

BUILDDIR = build

ARCHFLAGS += -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16 -mlittle-endian -mthumb
GDB_RELOAD_CMD =

# clang support
CC_VERSION_INFO := $(shell $(CC) --version)

ARM_CORTEXM_SYSROOT := \
  $(shell $(ARM_CC) $(ARCHFLAGS) -print-sysroot 2>&1)

# The directory where Newlib's libc.a & libm.a reside
# for the specific target architecture
ARM_CORTEXM_MULTI_DIR := \
  $(shell $(ARM_CC) $(ARCHFLAGS) -print-multi-directory 2>&1)

ifneq '' '$(findstring clang,$(CC_VERSION_INFO))'
# --- CLANG SPECIFIC ---

CFLAGS += \
  --sysroot=$(ARM_CORTEXM_SYSROOT) \
  --target=arm-none-eabi

LDFLAGS += \
  -L$(ARM_CORTEXM_SYSROOT)/lib/$(ARM_CORTEXM_MULTI_DIR)
else
# --- GCC SPECIFIC ---
# print memory usage if linking with gnu ld
LDFLAGS += -Wl,--print-memory-usage
# additional gcc-specific flags, used for computing stack usage
CFLAGS += -fstack-usage -fdump-rtl-dfinish -fdump-ipa-cgraph
endif

CFLAGS += \
  $(ARCHFLAGS) \
  -Os -ggdb3 -std=gnu11 \
  -fdebug-prefix-map=$(abspath .)=. \
  -ffunction-sections -fdata-sections \

CFLAGS += \
  -Werror \
  -Wall \
  -Wextra \
  -Wundef \

INCLUDES = \
  . \

CFLAGS += $(addprefix -I,$(INCLUDES))

# libc should be before libraries it depends on, eg libgcc and libnosys manually
# specify libgcc_nano.
#
# clang's auto search logic seems to pick up sysroot-based paths before the
# explicit reference to the arch variant libs. so let's just specify the literal
# path to the libraries we need.
LDFLAGS += \
  $(ARM_CORTEXM_SYSROOT)/lib/$(ARM_CORTEXM_MULTI_DIR)/libc_nano.a \
  $(ARM_CORTEXM_SYSROOT)/lib/$(ARM_CORTEXM_MULTI_DIR)/libg_nano.a \
  $(ARM_CORTEXM_SYSROOT)/lib/$(ARM_CORTEXM_MULTI_DIR)/libnosys.a \

LDFLAGS += \
  -nostdlib \
  $(shell $(ARM_CC) $(ARCHFLAGS) -print-libgcc-file-name 2>&1)

LDFLAGS += -Wl,--gc-sections,-Map,$@.map,--build-id

APP_SRCS += \
  src/app/main.c \
  $(wildcard src/common/*.c)

APP_OBJS = $(APP_SRCS:%.c=$(BUILDDIR)/%.o)

BOOTLOADER_SRCS += \
  src/bootloader/main.c \
  $(wildcard src/common/*.c)


BOOTLOADER_OBJS = $(BOOTLOADER_SRCS:%.c=$(BUILDDIR)/%.o)

all: $(BUILDDIR)/app.elf

# depfiles for tracking include changes
DEPFILES = $(OBJS:%.o=%.o.d)
DEPFLAGS = -MT $@ -MMD -MP -MF $@.d
-include $(DEPFILES)

$(BUILDDIR):
	mkdir -p $@

clean:
	$(RM) $(BUILDDIR)

$(BUILDDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(info Compiling $<)
	$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

$(BUILDDIR)/bootloader.ld: src/common/stm32f407.ld
	mkdir -p $(dir $@)
	$(info Generating linker script $@)
	$(CC) -DFLASH__=BOOTLOADER_FLASH -E -P -C -x c-header $^ > $@

$(BUILDDIR)/bootloader.elf: $(BUILDDIR)/bootloader.ld $(BOOTLOADER_OBJS)
	mkdir -p $(dir $@)
	$(info Linking $@)
	$(CC) $(CFLAGS) -T$^ $(LDFLAGS) -o $@
	arm-none-eabi-size $@

$(BUILDDIR)/app.ld: src/common/stm32f407.ld
	mkdir -p $(dir $@)
	$(info Generating linker script $@)
	$(CC) -DFLASH__=APP_FLASH -E -P -C -x c-header $^ > $@

$(BUILDDIR)/bootloader.bin: $(BUILDDIR)/bootloader.elf
	mkdir -p $(dir $@)
	$(info Generating binary $@)
	arm-none-eabi-objcopy -O binary $< $@

$(BUILDDIR)/bootloader.o: $(BUILDDIR)/bootloader.bin
	mkdir -p $(dir $@)
	arm-none-eabi-objcopy -I binary -O elf32-littlearm -B arm \
		--rename-section .data=.bootloader $^ $@

$(BUILDDIR)/app.elf: $(BUILDDIR)/app.ld $(APP_OBJS) $(BUILDDIR)/bootloader.o
	mkdir -p $(dir $@)
	$(info Linking $@)
	$(CC) $(CFLAGS) -T$^ $(LDFLAGS) -o $@
	arm-none-eabi-size $@

debug:
	openocd -f tools/stm32f4.openocd.cfg

gdb-bootloader: $(BUILDDIR)/bootloader.elf
	$(GDB) $^ -ex "source .gdb-startup" -ex "openocd-reload"

gdb: $(BUILDDIR)/app.elf
	$(GDB) $^ -ex "source .gdb-startup" -ex "openocd-reload"

.PHONY: all clean debug gdb gdb-bootloader
