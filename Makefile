# Standalone Makefile for Vienna 2.1.0 (Mac) - Targeting PPC and i386
# Built for Altivec Intelligence Cross-Compile Environment

APP_NAME = Vienna
PPC_SDK = /osxcross/target/SDK/MacOSX10.5.sdk
i386_SDK = /osxcross/target/SDK/MacOSX10.5.sdk

CC_PPC = oppc32-gcc
CC_X86 = o32-gcc

# --- Build Configuration ---
BUILD_DIR ?= build
BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INT_DIR = $(BUILD_DIR)/Intermediates
INC_DIR = $(INT_DIR)/include
OPT_FLAGS ?= -O2

# Absolute paths
VIENNA_DIR = $(CURDIR)/vienna

# Compilation Flags
CFLAGS = $(OPT_FLAGS) -g -Wall -Wno-import -Wno-trigraphs -I$(INC_DIR) -I$(VIENNA_DIR) -I$(VIENNA_DIR)/sqlite -I$(VIENNA_DIR)/CurlGetDate -F$(VIENNA_DIR) \
         -D"HAVE_USLEEP=1" -D"SQLITE_THREADSAFE=0" \
         -fno-stack-protector -fno-common -fno-zero-initialized-in-bss -fobjc-exceptions

# Linking Flags
LDFLAGS = -F$(VIENNA_DIR) -framework AppKit -framework Foundation -framework WebKit \
          -framework Carbon -framework Security -framework IOKit \
          -framework SystemConfiguration -framework Growl -framework Sparkle \
          -framework ApplicationServices -framework AddressBook -lcurl -lobjc

# Source Discovery
ORIG_SOURCES_M = $(shell find vienna -maxdepth 1 -name "*.m" -not -path "*/.*")
ORIG_SOURCES_M += vienna/CurlGetDate/CurlGetDate.m
ORIG_SOURCES_C = vienna/sqlite/sqlite3.c

# Shadow Paths
PPC_SHADOW_DIR = $(INT_DIR)/ppc/src
X86_SHADOW_DIR = $(INT_DIR)/i386/src

# Object file mapping
PPC_OBJS_M = $(addprefix $(INT_DIR)/ppc/obj/, $(notdir $(ORIG_SOURCES_M:.m=.o)))
PPC_OBJS_C = $(INT_DIR)/ppc/obj/sqlite3.o
PPC_OBJS = $(PPC_OBJS_M) $(PPC_OBJS_C)

X86_OBJS_M = $(addprefix $(INT_DIR)/i386/obj/, $(notdir $(ORIG_SOURCES_M:.m=.o)))
X86_OBJS_C = $(INT_DIR)/i386/obj/sqlite3.o
X86_OBJS = $(X86_OBJS_M) $(X86_OBJS_C)

# Resource Discovery
RESOURCE_FILES = $(shell find vienna -maxdepth 1 \( -name "*.tiff" -o -name "*.plist" -o -name "*.icns" -o -name "*.rtf" -o -name "*.html" -o -name "*.png" -o -name "*.scriptSuite" -o -name "*.scriptTerminology" \) -not -path "*/.*")
LPROJ_DIRS = $(shell find vienna -maxdepth 1 -name "*.lproj" -type d -not -path "*/.*")

.PHONY: all clean debug release

all: release

debug:
	@$(MAKE) --no-print-directory build_all BUILD_DIR=build-debug OPT_FLAGS=-O0
	@echo " [6/6] Zipping debug bundle..."
	@cd build-debug && zip -q -r Vienna.zip Vienna.app
	@echo "--- Debug Build Complete: build-debug/Vienna.app ---"

release:
	@$(MAKE) --no-print-directory build_all BUILD_DIR=build-release OPT_FLAGS=-O3
	@echo " [6/6] Zipping release bundle..."
	@cd build-release && zip -q -r Vienna.zip Vienna.app
	@echo "--- Release Build Complete: build-release/Vienna.app ---"

build_all: $(BUNDLE)

clean:
	rm -rf build build-debug build-release

# Link Universal Binary
$(BUNDLE)/Contents/MacOS/$(APP_NAME): $(INT_DIR)/ppc.bin $(INT_DIR)/i386.bin
	@mkdir -p $(dir $@)
	@echo " [5/6] Merging fat binary (ppc, i386)..."
	@lipo -create $^ -output $@

# App Bundle Structure & Resources
$(BUNDLE): $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	@echo " [4/6] Building app bundle & copying resources..."
	@mkdir -p $(BUNDLE)/Contents/Resources
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Styles
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Scripts
	@mkdir -p $(BUNDLE)/Contents/Frameworks
	@cp $(VIENNA_DIR)/Info.plist $(BUNDLE)/Contents/
	@echo "APPL????" > $(BUNDLE)/Contents/PkgInfo
	@cp -R $(RESOURCE_FILES) $(BUNDLE)/Contents/Resources/
	@for dir in $(LPROJ_DIRS); do \
		cp -R $$dir $(BUNDLE)/Contents/Resources/; \
	done
	@cp -R $(VIENNA_DIR)/Styles/* $(BUNDLE)/Contents/SharedSupport/Styles/
	@cp -R $(VIENNA_DIR)/scripts/* $(BUNDLE)/Contents/SharedSupport/Scripts/
	@cp -R $(VIENNA_DIR)/Growl.framework $(BUNDLE)/Contents/Frameworks/
	@if [ -d $(VIENNA_DIR)/Sparkle.framework ]; then cp -R $(VIENNA_DIR)/Sparkle.framework $(BUNDLE)/Contents/Frameworks/; fi

# PPC Slice
$(INT_DIR)/ppc.bin: $(PPC_OBJS)
	@echo " [3/6] Linking ppc slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) -arch ppc -isysroot $(PPC_SDK) $^ $(LDFLAGS) -o $@

# i386 Slice
$(INT_DIR)/i386.bin: $(X86_OBJS)
	@echo " [3/6] Linking i386 slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) -arch i386 -isysroot $(i386_SDK) $^ $(LDFLAGS) -o $@

# Pattern Rules for PPC Objects
$(INT_DIR)/ppc/obj/%.o: $(PPC_SHADOW_DIR)/%.m $(PPC_SHADOW_DIR)/Constants.h $(INC_DIR)/BacktrackArray.h
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS) -x objective-c -arch ppc -isysroot $(PPC_SDK) -I$(PPC_SHADOW_DIR) -c $< -o $@

$(INT_DIR)/ppc/obj/sqlite3.o: $(VIENNA_DIR)/sqlite/sqlite3.c
	@mkdir -p $(dir $@)
	@echo "  > ppc: sqlite3.c"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS) -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

# Pattern Rules for i386 Objects
$(INT_DIR)/i386/obj/%.o: $(X86_SHADOW_DIR)/%.m $(X86_SHADOW_DIR)/Constants.h $(INC_DIR)/BacktrackArray.h
	@mkdir -p $(dir $@)
	@echo "  > i386: $(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS) -x objective-c -arch i386 -isysroot $(i386_SDK) -I$(X86_SHADOW_DIR) -c $< -o $@

$(INT_DIR)/i386/obj/sqlite3.o: $(VIENNA_DIR)/sqlite/sqlite3.c
	@mkdir -p $(dir $@)
	@echo "  > i386: sqlite3.c"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

# Shadow Source Generation Rules
$(PPC_SHADOW_DIR)/%.m: $(VIENNA_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo '#import "Vienna_Prefix.pch"' > $@
	@cat $< >> $@

$(PPC_SHADOW_DIR)/%.m: $(VIENNA_DIR)/CurlGetDate/%.m
	@mkdir -p $(dir $@)
	@echo '#import "Vienna_Prefix.pch"' > $@
	@cat $< >> $@

$(PPC_SHADOW_DIR)/Constants.h: $(VIENNA_DIR)/Constants.h
	@mkdir -p $(dir $@)
	@sed 's/^const AEKeyword/extern const AEKeyword/' $< > $@

$(X86_SHADOW_DIR)/%.m: $(VIENNA_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo '#import "Vienna_Prefix.pch"' > $@
	@cat $< >> $@

$(X86_SHADOW_DIR)/%.m: $(VIENNA_DIR)/CurlGetDate/%.m
	@mkdir -p $(dir $@)
	@echo '#import "Vienna_Prefix.pch"' > $@
	@cat $< >> $@

$(X86_SHADOW_DIR)/Constants.h: $(VIENNA_DIR)/Constants.h
	@mkdir -p $(dir $@)
	@sed 's/^const AEKeyword/extern const AEKeyword/' $< > $@

# Case-sensitivity fix for BacktrackArray.h
$(INC_DIR)/BacktrackArray.h: $(VIENNA_DIR)/BackTrackArray.h
	@mkdir -p $(dir $@)
	@git -C $(VIENNA_DIR) show HEAD:BackTrackArray.h > $@
