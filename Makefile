
# Common makefile section for applications running on XMC4800.
ifeq ($(SRC_APP_DIR),)
$(error SRC_APP_DIR is not defined)
endif

SRC_PROJ_DIR  = /home/docker/project
SRC_LIB_DIR   = $(SRC_PROJ_DIR)/libraries/ema_filter
BUILD_DIR     = $(SRC_PROJ_DIR)/build
OBJ_DIR       = $(BUILD_DIR)/objs
TOOLCHAIN     = arm-none-eabi
UC            = XMC4800
UC_TYPE       = XMC4800_F144x2048
CPU           = cortex-m4
FPU           = fpv4-sp-d16

FLOAT_ABI     = hard
LIBS          = -larm_cortexM4lf_math -lm
GDB_ARGS      = -ex "target remote :2331" -ex "monitor reset" -ex "load" -ex "monitor reset" -ex "monitor go"
STARTUP_DEFS=-D__STARTUP_CLEAR_BSS -D__START=main
XMC_LIB_VER   = 2.1.22
STACK_SIZE   ?= 16384


# Application files.
SRC_C         = $(wildcard $(SRC_APP_DIR)/*.c $(SRC_LIB_DIR)/*.c)
SRC_S         = $(wildcard $(SRC_APP_DIR)/*.s $(SRC_LIB_DIR)/*.s)


# CMSIS files.
CMSIS_DIR = $(HOME)/opt/XMC_Peripheral_Library_v$(XMC_LIB_VER)/CMSIS
CMSIS_INFINEON_SRC = $(CMSIS_DIR)/Infineon/$(UC)_series/Source
SRC_CMSIS_C = $(CMSIS_INFINEON_SRC)/system_$(UC).c
SRC_CMSIS_S = $(CMSIS_INFINEON_SRC)/GCC/startup_$(UC).S
LINKER_FILE = $(CMSIS_INFINEON_SRC)/GCC/XMC4800x2048.ld
SRC_C += $(SRC_CMSIS_C)
SRC_S += $(SRC_CMSIS_S)


# XMCLib files.
XMCLIB = $(HOME)/opt/XMC_Peripheral_Library_v$(XMC_LIB_VER)/XMCLib
SRC_C += $(wildcard $(XMCLIB)/src/*.c)


# Third party libraries.
NEWLIB = $(HOME)/opt/XMC_Peripheral_Library_v$(XMC_LIB_VER)/ThirdPartyLibraries/Newlib
SRC_C += $(NEWLIB)/syscalls.c

# ccache to speed up compilation.
CC_PREFIX ?= ccache

# Toolchain.
AS   = $(TOOLCHAIN)-as
CC   = $(CC_PREFIX) $(TOOLCHAIN)-gcc
CP   = $(TOOLCHAIN)-objcopy
OD   = $(TOOLCHAIN)-objdump
GDB  = $(TOOLCHAIN)-gdb
SIZE = $(TOOLCHAIN)-size


# Compiler and linker flags.
CFLAGS = -mthumb -mcpu=$(CPU) -mfpu=$(FPU) -mfloat-abi=$(FLOAT_ABI)
CFLAGS+= -Os -g -ffunction-sections -fdata-sections -fno-common
CFLAGS+= -fmessage-length=0 -fdiagnostics-color=auto
CFLAGS+= -MD -std=c99 -Wall -fms-extensions
CFLAGS+= -DARM_MATH_CM4 -D$(UC_TYPE)
CFLAGS+= -I$(CMSIS_DIR)/Include -I$(CMSIS_DIR)/Infineon/Include
CFLAGS+= -I$(CMSIS_DIR)/Infineon/$(UC)_series/Include
CFLAGS+= -I$(XMCLIB)/inc
CFLAGS+= -I$(SRC_LIB_DIR)
# Need following option for LTO as LTO will treat retarget functions as
# unused without following option
CFLAGS+= -fno-builtin
ASFLAGS = -mthumb -target $(TOOLCHAIN) -mcpu=$(CPU) -marm
ASFLAGS+= -O0 -ffunction-sections -fdata-sections
ASFLAGS+= -MD -Wall -fms-extensions
ASFLAGS+= -g3 -fmessage-length=0 -I$(CMSIS_DIR)/Include
ASFLAGS+= -I$(CMSIS_DIR)/Infineon/Include
ASFLAGS+= -I$(CMSIS_DIR)/Infineon/$(UC)_series/Include
ASFLAGS+= -no-integrated-as -ccc-gcc-name arm-none-eabi-gcc
LDFLAGS = -nostartfiles -L$(CMSIS_DIR)/DSP/Lib/GCC -Wl,--fatal-warnings,--gc-sections
LDFLAGS+= -Xlinker --defsym=stack_size=$(STACK_SIZE)
# options from retarget example
CPFLAGS = -O binary
ODFLAGS = -S


# We need to deal with assembler files ending in .s and .S
INTERM_S_OBJS = $(SRC_S:.S=.s)
INTERM_S_C_OBJS = $(SRC_C:.c=.o) $(INTERM_S_OBJS:.s=.o)
OBJS  = $(addprefix $(OBJ_DIR)/, $(notdir $(INTERM_S_C_OBJS)))


# Automatic dependency files (only C files).
DEP_OBJS  = $(addprefix $(OBJ_DIR)/, $(notdir $(SRC_C:.c=.o)))
DEPS = $(patsubst %.o,%.d,$(DEP_OBJS))


# Used for makefile debugging.
print-%: ; @echo $*=$($*)


VPATH = $(CURDIR)
VPATH+= $(SRC_LIB_DIR)
VPATH+= $(NEWLIB)
VPATH+= $(XMCLIB)/src
VPATH+= $(CMSIS_INFINEON_SRC)
VPATH+= $(CMSIS_INFINEON_SRC)/GCC


#############################################################################
# Rules.
#############################################################################
all:    $(BUILD_DIR)/$(IMAGE).bin

$(BUILD_DIR)/$(IMAGE).bin: $(BUILD_DIR)/$(IMAGE).axf
	$(CP) $(CPFLAGS) $(BUILD_DIR)/$(IMAGE).axf $(BUILD_DIR)/$(IMAGE).bin
	$(OD) $(ODFLAGS) $(BUILD_DIR)/$(IMAGE).axf > $(BUILD_DIR)/$(IMAGE).lst
	$(SIZE) $(BUILD_DIR)/$(IMAGE).axf

$(BUILD_DIR)/$(IMAGE).axf: $(OBJS)
	@mkdir -p $(BUILD_DIR)
	$(CC) -T $(LINKER_FILE) $(CFLAGS) $(LDFLAGS) -o $@ $^ $(LIBS)

$(OBJ_DIR)/%.o : %.c
	$(CC) -c $(CFLAGS) -MMD  $< -o $(OBJ_DIR)/$(@F)

include $(DEPS)

$(DEPS): ;

$(OBJ_DIR)/%.o : %.S %.s
	$(AS) $< -o $(OBJ_DIR)/$(@F)

flash: $(BUILD_DIR)/$(IMAGE).axf
	$(GDB) $(BUILD_DIR)/$(IMAGE).axf $(GDB_ARGS)

clean:
	@rm -f $(BUILD_DIR)/$(IMAGE).* $(OBJS) $(OBJS:.o=.d)

.PHONY: all flash clean
