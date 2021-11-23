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
  -Wl,--gc-sections,-Map,$@.map \
  -Wl,--print-memory-usage

APP_SRCS += \
  src/app/main.c \
  src/common/noinit.c \

APP_OBJS = $(APP_SRCS:%.c=$(BUILDDIR)/%.o)

BOOTLOADER_SRCS += \
  src/bootloader/main.c \
  src/common/noinit.c \

BOOTLOADER_OBJS = $(BOOTLOADER_SRCS:%.c=$(BUILDDIR)/%.o)

all: $(BUILDDIR)/app.elf $(BUILDDIR)/bootloader.elf

# depfiles for tracking include changes
DEPFILES = $(OBJS:%.o=%.o.d)
DEPFLAGS = -MT $@ -MMD -MP -MF $@.d
-include $(DEPFILES)

$(BUILDDIR):
	mkdir -p $@

clean:
	$(RM) $(BUILDDIR)

# compile .c files to .o files
$(BUILDDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(info Compiling $<)
	$(CC) $(CFLAGS) $(DEPFLAGS) -c $< -o $@

# link bootloader elf
$(BUILDDIR)/bootloader.elf: src/bootloader/stm32f407.ld $(BOOTLOADER_OBJS)
	mkdir -p $(dir $@)
	$(info Linking $@)
	$(CC) $(CFLAGS) -T$^ $(LDFLAGS) -o $@
	arm-none-eabi-size $@

# link application elf
$(BUILDDIR)/app.elf: src/app/stm32f407.ld $(APP_OBJS)
	mkdir -p $(dir $@)
	$(info Linking $@)
	$(CC) $(CFLAGS) -T$^ $(LDFLAGS) -o $@
	arm-none-eabi-size $@

debug:
	openocd -f tools/stm32f4.openocd.cfg

gdb-bootloader: $(BUILDDIR)/app.elf $(BUILDDIR)/bootloader.elf
# load (flash) application and bootloader, and debug bootloader elf
	$(GDB) -ex "target extended-remote :3333" -ex "monitor reset halt" \
		-ex "load $(BUILDDIR)/app.elf" -ex "load $(BUILDDIR)/bootloader.elf" \
		-ex "monitor reset init" $(BUILDDIR)/bootloader.elf

gdb-app: $(BUILDDIR)/app.elf $(BUILDDIR)/bootloader.elf
# load (flash) application and bootloader, and debug application elf
	$(GDB) -ex "target extended-remote :3333" -ex "monitor reset halt" \
		-ex "load $(BUILDDIR)/app.elf" -ex "load $(BUILDDIR)/bootloader.elf" \
		-ex "monitor reset init" $(BUILDDIR)/app.elf

.PHONY: all clean debug gdb gdb-bootloader
