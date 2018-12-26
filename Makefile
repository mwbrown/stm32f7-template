
# Check for the presence of STM32CUBE_F7
ifndef STM32CUBE_F7
  $(error STM32CUBE_F7 must be set to the STM32Cube installation.)
endif

# Toolchain Configuration
PREFIX     := arm-none-eabi-
CC         := $(PREFIX)gcc
OBJCOPY    := $(PREFIX)objcopy
OBJDUMP    := $(PREFIX)objdump

# Source Directories
CMSIS_DIR  := $(STM32CUBE_F7)/Drivers/CMSIS
HAL_DIR    := $(STM32CUBE_F7)/Drivers/STM32F7xx_HAL_Driver
BSP_DIR    := $(STM32CUBE_F7)/Drivers/BSP/STM32746G-Discovery
COMP_DIR   := $(STM32CUBE_F7)/Drivers/BSP/Components

# Build variables
OBJDIR     := build
IMAGE_NAME := f7-tmpl

INCLUDES :=                                          \
	-Isrc                                            \
	-I$(CMSIS_DIR)/Include                           \
	-I$(CMSIS_DIR)/Device/ST/STM32F7xx/Include       \
	-I$(HAL_DIR)/Inc                                 \

DEFINES := -DSTM32F746xx

# FIXME add FPU support
CPUFLAGS := -mcpu=cortex-m7 -mthumb

CFLAGS  = $(CPUFLAGS) -g -Os -ffreestanding -ffunction-sections -fdata-sections -Wall $(INCLUDES) $(DEFINES) 
LDFLAGS = $(CPUFLAGS) -Wl,-Map=$(IMAGE_NAME).map -T STM32F746NGHx_FLASH.ld -specs=nano.specs -Wl,--gc-sections

# Make implicit function declarations error out.
CFLAGS += -Werror=implicit-function-declaration

APP_SOURCES :=                  \
	src/main.c                  \
	src/system_stm32f7xx.c

HAL_SOURCES :=                                \
	$(HAL_DIR)/Src/stm32f7xx_hal.c            \
	$(HAL_DIR)/Src/stm32f7xx_hal_pwr_ex.c     \
	$(HAL_DIR)/Src/stm32f7xx_hal_cortex.c     \
	$(HAL_DIR)/Src/stm32f7xx_hal_rcc.c 

STARTUP_SOURCES :=              \
	src/startup_stm32f746xx.s

SOURCES_C := $(APP_SOURCES) $(HAL_SOURCES)
SOURCES_S := $(STARTUP_SOURCES)

OBJECTS_C := $(addprefix $(OBJDIR)/, $(SOURCES_C:.c=.c.o))
OBJECTS_S := $(addprefix $(OBJDIR)/, $(SOURCES_S:.s=.s.o))

OBJECTS := $(OBJECTS_C) $(OBJECTS_S)

all: $(IMAGE_NAME).hex

.PHONY: clean flash disasm

# Mark the objects as precious to enable fast rebuilds.
.PRECIOUS: $(OBJDIR)/%.o

#
# Phony Targets
#

clean:
	rm -f $(IMAGE_NAME).elf $(IMAGE_NAME).hex $(IMAGE_NAME).bin $(IMAGE_NAME).map
	rm -rf $(OBJDIR)/

flash: $(IMAGE_NAME).hex
	st-flash --reset --format ihex write $(IMAGE_NAME).hex

disasm: $(IMAGE_NAME).elf
	$(OBJDUMP) -d $< > $(IMAGE_NAME).disasm

#
# Top-level Targets
#

$(IMAGE_NAME).elf: $(OBJECTS)
	$(CC) $(LDFLAGS) -o $@ $^

#
# Pattern Rules
#

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@

%.hex: %.elf
	$(OBJCOPY) -O ihex $< $@

-include $(OBJECTS_C:.o=.d)
-include $(OBJECTS_S:.o=.d)

$(OBJDIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<
	@$(CC) $(CFLAGS) -MM -MT $@ $< > $(OBJDIR)/$*.d

$(OBJDIR)/%.s.o: %.s
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<
	@$(CC) $(CFLAGS) -MM -MT $@ $< > $(OBJDIR)/$*.d