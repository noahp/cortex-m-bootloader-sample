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

ARCHFLAGS +=
GDB_RELOAD_CMD =

CFLAGS += \
  -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16 \
  -Os -ggdb3 -std=c11 \
  -fdebug-prefix-map=$(abspath .)=. \
  -I. \
  -ffunction-sections -fdata-sections \
  -Werror \
  -Wall \
  -Wextra \
  -Wundef \

LDFLAGS += \
  --specs=rdimon.specs \
  --specs=nano.specs \
  -Wl,--gc-sections,-Map,$@.map,--build-id \
  -Wl,--print-memory-usage

APP_SRCS += \
  src/app/main.c \
  src/common/noinit.c \

APP_OBJS = $(APP_SRCS:%.c=$(BUILDDIR)/%.o)

BOOTLOADER_SRCS += \
  src/bootloader/main.c \
  src/common/noinit.c \

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

# Generate a binary copy of the bootloader (raw image)
$(BUILDDIR)/bootloader.bin: $(BUILDDIR)/bootloader.elf
	mkdir -p $(dir $@)
	$(info Generating binary $@)
	arm-none-eabi-objcopy -O binary $< $@

# Generate an object file containing the raw binary bootloader image.
# This will be linked into the application at the `.bootloader` output section.
$(BUILDDIR)/bootloader.o: $(BUILDDIR)/bootloader.bin
	mkdir -p $(dir $@)
	arm-none-eabi-objcopy -I binary -O elf32-littlearm -B arm \
		--rename-section .data=.bootloader $^ $@

$(BUILDDIR)/app.elf: $(BUILDDIR)/app.ld $(BUILDDIR)/bootloader.o $(APP_OBJS)
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
