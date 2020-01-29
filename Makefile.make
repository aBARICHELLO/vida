.SUFFIXES:
ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitPro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/3ds_rules

export VERSTRING := v0.1

MAKEFILE    := Makefile.make
TARGET      := $(notdir $(CURDIR))
BUILD       := build
SOURCES     := $(sort $(dir $(wildcard src/*/)))
DATA        := data
INCLUDES    := $(sort $(dir $(wildcard include/*/))) $(sort $(dir $(wildcard src/*/)))

APP_TITLE       := Your awesome Homebrew $(VERSTRING)
APP_DESCRIPTION := Some awesome software that does something
APP_AUTHOR      := You

ARCH := -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft
CFLAGS := -g -Wall -O2 -mword-relocations \
          -fomit-frame-pointer -ffunction-sections \
          $(ARCH)
CFLAGS += $(INCLUDE) -DARM11 -D_3DS
CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions -std=gnu++2a
CXXFLAGS += $(MODE)
ASFLAGS := -g $(ARCH)
LDFLAGS = -specs=3dsx.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map)
LIBS := -lm3dia -lcitro2d -lcitro3d -lctru
LIBDIRS	:= $(PORTLIBS) $(CTRULIB)

ifneq ($(BUILD),$(notdir $(CURDIR)))

export OUTPUT := $(CURDIR)/$(TARGET)
export TOPDIR := $(CURDIR)

export VPATH := $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
   $(foreach dir,$(GRAPHICS),$(CURDIR)/$(dir)) \
   $(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR := $(CURDIR)/$(BUILD)

CFILES      := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES    := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES      := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
PICAFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.v.pica)))
SHLISTFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.shlist)))
GFXFILES    := $(foreach dir,$(GRAPHICS),$(notdir $(wildcard $(dir)/*.t3s)))
BINFILES    := $(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

ifeq ($(strip $(CPPFILES)),)
    export LD := $(CC)
else
    export LD := $(CXX)
endif

ifeq ($(GFXBUILD),$(BUILD))
    export T3XFILES := $(GFXFILES:.t3s=.t3x)
else
    export ROMFS_T3XFILES := $(patsubst %.t3s, $(GFXBUILD)/%.t3x, $(GFXFILES))
    export T3XHFILES := $(patsubst %.t3s, $(BUILD)/%.h, $(GFXFILES))
endif

export OFILES_SOURCES  := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)
export OFILES_BIN := $(addsuffix .o,$(BINFILES)) \
    $(PICAFILES:.v.pica=.shbin.o) $(SHLISTFILES:.shlist=.shbin.o) \
    $(addsuffix .o,$(T3XFILES))
export OFILES := $(OFILES_BIN) $(OFILES_SOURCES)

export HFILES := $(PICAFILES:.v.pica=_shbin.h) $(SHLISTFILES:.shlist=_shbin.h) \
   $(addsuffix .h,$(subst .,_,$(BINFILES))) \
   $(GFXFILES:.t3s=.h)

export INCLUDE := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
   $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
   -I$(CURDIR)/$(BUILD)

export LIBPATHS := $(foreach dir,$(LIBDIRS),-L$(dir)/lib)
export _3DSXDEPS := $(if $(NO_SMDH),,$(OUTPUT).smdh)

ifeq ($(strip $(ICON)),)
    icons := $(wildcard *.png)
    ifneq (,$(findstring $(TARGET).png,$(icons)))
    export APP_ICON := $(TOPDIR)/$(TARGET).png
else
    ifneq (,$(findstring icon.png,$(icons)))
        export APP_ICON := $(TOPDIR)/icon.png
    endif
endif
else
    export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_SMDH)),)
    export _3DSXFLAGS += --smdh=$(CURDIR)/$(TARGET).smdh
endif

ifneq ($(ROMFS),)
    export _3DSXFLAGS += --romfs=$(CURDIR)/$(ROMFS)
endif

.PHONY: all clean
#---------------------------------------------------------------------------------
all: $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(T3XHFILES)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/$(MAKEFILE)

$(BUILD):
	@mkdir -p $@

ifneq ($(GFXBUILD),$(BUILD))
$(GFXBUILD):
	@mkdir -p $@
endif

ifneq ($(DEPSDIR),$(BUILD))
$(DEPSDIR):
	@mkdir -p $@
endif

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).3dsx $(OUTPUT).smdh $(TARGET).elf $(GFXBUILD)/*.t3x
else

# main targets
$(OUTPUT).3dsx: $(OUTPUT).elf $(_3DSXDEPS)
$(OFILES_SOURCES): $(HFILES)
$(OUTPUT).elf: $(OFILES)

-include $(DEPSDIR)/*.d
endif
