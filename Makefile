# Standalone Makefile for Vienna 2.2.0 (Mac) - Targeting PPC and i386
# Built for Altivec Intelligence Cross-Compile Environment

APP_NAME = Vienna
PPC_SDK = /osxcross/target/SDK/MacOSX10.5.sdk
i386_SDK = /osxcross/target/SDK/MacOSX10.5.sdk

CC_PPC = oppc32-gcc
CC_X86 = o32-gcc
AR_PPC = powerpc-apple-darwin9-ar
AR_X86 = i386-apple-darwin9-ar

# --- Build Configuration ---
BUILD_DIR ?= build
BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
INT_DIR = $(BUILD_DIR)/Intermediates
INC_DIR = $(INT_DIR)/include
FW_DIR = $(BUILD_DIR)/Frameworks
OPT_FLAGS ?= -O2

# Absolute paths
VIENNA_DIR = $(CURDIR)/vienna
PATCHES_DIR = $(CURDIR)/patches
STUBS_H = $(CURDIR)/source/stubs.h
STUBS_M = $(CURDIR)/source/stubs.m
PSM_DIR = $(CURDIR)/deps/PSMTabBarControl
PPC_SRC_DIR = $(INT_DIR)/ppc/src
X86_SRC_DIR = $(INT_DIR)/i386/src

# Compilation Flags
CFLAGS_COMMON = $(OPT_FLAGS) -g -Wall -Wno-import -Wno-trigraphs -std=gnu99 -I$(INC_DIR) -I$(VIENNA_DIR) -I$(VIENNA_DIR)/sqlite -I$(VIENNA_DIR)/CurlGetDate \
         -I$(PSM_DIR) -F$(VIENNA_DIR) -F$(FW_DIR) \
         -D"HAVE_USLEEP=1" -D"SQLITE_THREADSAFE=0" \
         -fno-stack-protector -fno-common -fno-zero-initialized-in-bss

# ObjC specific flags
OBJC_FLAGS = -fobjc-exceptions -include $(STUBS_H)

CFLAGS_PPC_M = $(CFLAGS_COMMON) -I$(PPC_SRC_DIR) $(OBJC_FLAGS)
CFLAGS_X86_M = $(CFLAGS_COMMON) -I$(X86_SRC_DIR) $(OBJC_FLAGS)

CFLAGS_PPC_C = $(CFLAGS_COMMON)
CFLAGS_X86_C = $(CFLAGS_COMMON)

# Linking Flags
# -ObjC forces loading all classes/categories from frameworks
# -Wl,-S strips local symbols during link to reduce linker memory usage
LDFLAGS_BASE = -F$(VIENNA_DIR) -F$(FW_DIR) -framework AppKit -framework Foundation -framework WebKit \
          -framework Carbon -framework Security -framework IOKit \
          -framework SystemConfiguration -framework ApplicationServices -framework AddressBook \
          -lcurl -lobjc -ObjC -Wl,-S

# Source Discovery
ORIG_SOURCES_M = $(shell find vienna -maxdepth 1 -name "*.m" -not -path "*/.*")
ORIG_SOURCES_M += vienna/CurlGetDate/CurlGetDate.m
ORIG_HEADERS = $(shell find vienna -maxdepth 1 -name "*.h" -not -path "*/.*")
ORIG_SOURCES_C = vienna/sqlite/sqlite3.c

# PSMTabBarControl sources
PSM_SOURCES = $(shell ls $(PSM_DIR)/*.m | grep -vE "Inspector|Integration|Plugin|Demo")
PSM_HEADERS = $(shell ls $(PSM_DIR)/*.h | grep -vE "Inspector|Integration|Plugin|Demo")

# Object file mapping
PPC_VIENNA_OBJS = $(addprefix $(INT_DIR)/ppc/obj/, $(notdir $(ORIG_SOURCES_M:.m=.o) $(ORIG_SOURCES_C:.c=.o))) $(INT_DIR)/ppc/obj/stubs.o
X86_VIENNA_OBJS = $(addprefix $(INT_DIR)/i386/obj/, $(notdir $(ORIG_SOURCES_M:.m=.o) $(ORIG_SOURCES_C:.c=.o))) $(INT_DIR)/i386/obj/stubs.o

PPC_PSM_OBJS = $(addprefix $(INT_DIR)/ppc/obj/psm/, $(notdir $(PSM_SOURCES:.m=.o)))
X86_PSM_OBJS = $(addprefix $(INT_DIR)/i386/obj/psm/, $(notdir $(PSM_SOURCES:.m=.o)))

# Shadow Headers
PPC_SHADOW_HEADERS = $(addprefix $(PPC_SRC_DIR)/, $(notdir $(ORIG_HEADERS)))
X86_SHADOW_HEADERS = $(addprefix $(X86_SRC_DIR)/, $(notdir $(ORIG_HEADERS)))

# Resources
RESOURCE_FILES = $(shell find vienna -maxdepth 1 \( -name "*.tiff" -o -name "*.plist" -o -name "*.icns" -o -name "*.rtf" -o -name "*.html" -o -name "*.png" -o -name "*.scriptSuite" -o -name "*.scriptTerminology" -o -name "*.nib" \) -not -path "*/.*")
LPROJ_DIRS = $(shell find vienna -maxdepth 1 -name "*.lproj" -type d -not -path "*/.*")
PSM_RESOURCE_FILES = $(shell find $(PSM_DIR) -maxdepth 1 \( -name "*.png" -o -name "*.jpg" \) -not -path "*/.*")
PSM_LPROJ_DIRS = $(shell find $(PSM_DIR) -maxdepth 1 -name "*.lproj" -type d -not -path "*/.*")

.PHONY: all clean debug release build_all
.PRECIOUS: $(PPC_SRC_DIR)/%.m $(X86_SRC_DIR)/%.m $(PPC_SRC_DIR)/%.h $(X86_SRC_DIR)/%.h

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

build_all: $(INC_DIR)/PSMTabBarControl/.dir $(FW_DIR)/PSMTabBarControl.framework/PSMTabBarControl $(BUNDLE)

clean:
	rm -rf build build-debug build-release *.o

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
	@for dir in $(LPROJ_DIRS); do cp -R $$dir $(BUNDLE)/Contents/Resources/; done
	@cp -R $(VIENNA_DIR)/Styles/* $(BUNDLE)/Contents/SharedSupport/Styles/
	@cp -R $(VIENNA_DIR)/scripts/* $(BUNDLE)/Contents/SharedSupport/Scripts/
	@cp -R $(PSM_RESOURCE_FILES) $(BUNDLE)/Contents/Resources/
	@for dir in $(PSM_LPROJ_DIRS); do cp -R $$dir $(BUNDLE)/Contents/Resources/; done
	@cp -R $(FW_DIR)/PSMTabBarControl.framework $(BUNDLE)/Contents/Frameworks/

# PSM Dynamic Framework
$(FW_DIR)/PSMTabBarControl.framework/PSMTabBarControl: $(INT_DIR)/ppc/PSMTabBarControl.dylib $(INT_DIR)/i386/PSMTabBarControl.dylib
	@mkdir -p $(dir $@)
	@echo "  > merging fat PSMTabBarControl dylib..."
	@lipo -create $^ -output $@

$(INT_DIR)/ppc/PSMTabBarControl.dylib: $(PPC_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > ppc: linking PSMTabBarControl dylib"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) -dynamiclib -arch ppc -isysroot $(PPC_SDK) \
		-install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
		$^ -framework AppKit -framework Foundation -lobjc -o $@

$(INT_DIR)/i386/PSMTabBarControl.dylib: $(X86_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > i386: linking PSMTabBarControl dylib"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) -dynamiclib -arch i386 -isysroot $(i386_SDK) \
		-install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
		$^ -framework AppKit -framework Foundation -lobjc -o $@

# PPC Slice
$(INT_DIR)/ppc.bin: $(PPC_SHADOW_HEADERS) $(PPC_VIENNA_OBJS) $(INT_DIR)/ppc/PSMTabBarControl.dylib
	@echo " [3/6] Linking ppc slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) -arch ppc -isysroot $(PPC_SDK) \
		$(filter %.o, $^) $(INT_DIR)/ppc/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

# i386 Slice
$(INT_DIR)/i386.bin: $(X86_SHADOW_HEADERS) $(X86_VIENNA_OBJS) $(INT_DIR)/i386/PSMTabBarControl.dylib
	@echo " [3/6] Linking i386 slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) -arch i386 -isysroot $(i386_SDK) \
		$(filter %.o, $^) $(INT_DIR)/i386/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

# Pattern Rules
$(INT_DIR)/ppc/obj/%.o: $(PPC_SRC_DIR)/%.m $(INC_DIR)/BacktrackArray.h
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_PPC_M) -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

$(INT_DIR)/ppc/obj/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: psm/$(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_PPC_M) -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

$(INT_DIR)/ppc/obj/sqlite3.o: $(VIENNA_DIR)/sqlite/sqlite3.c
	@mkdir -p $(dir $@)
	@echo "  > ppc: sqlite3.c"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_PPC_C) -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

$(INT_DIR)/ppc/obj/stubs.o: $(STUBS_M)
	@mkdir -p $(dir $@)
	@echo "  > ppc: stubs.m"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_COMMON) $(OBJC_FLAGS) -x objective-c -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

$(INT_DIR)/i386/obj/%.o: $(X86_SRC_DIR)/%.m $(INC_DIR)/BacktrackArray.h
	@mkdir -p $(dir $@)
	@echo "  > i386: $(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_X86_M) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

$(INT_DIR)/i386/obj/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: psm/$(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_X86_M) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

$(INT_DIR)/i386/obj/sqlite3.o: $(VIENNA_DIR)/sqlite/sqlite3.c
	@mkdir -p $(dir $@)
	@echo "  > i386: sqlite3.c"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_X86_C) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

$(INT_DIR)/i386/obj/stubs.o: $(STUBS_M)
	@mkdir -p $(dir $@)
	@echo "  > i386: stubs.m"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_X86_M) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

define prepare_shadow_m
	@mkdir -p $(dir $@)
	@cp $< $@
	@if [ -f $(PATCHES_DIR)/$(notdir $<).patch ]; then patch -s -f $@ < $(PATCHES_DIR)/$(notdir $<).patch; fi
	@sed -i 's|#import <Growl/.*>||g' $@
	@sed -i 's|#import <Sparkle/.*>||g' $@
	@sed -i '1i #import "Vienna_Prefix.pch"' $@
endef

define prepare_shadow_h
	@mkdir -p $(dir $@)
	@cp $< $@
	@if [ -f $(PATCHES_DIR)/$(notdir $<).patch ]; then patch -s -f $@ < $(PATCHES_DIR)/$(notdir $<).patch; fi
	@sed -i 's|#import <Growl/.*>||g' $@
	@sed -i 's|#import <Sparkle/.*>||g' $@
	@sed -i 's|[ ]*<GrowlApplicationBridgeDelegate>||g' $@
endef

$(PPC_SRC_DIR)/%.m: $(VIENNA_DIR)/%.m
	$(call prepare_shadow_m)
$(PPC_SRC_DIR)/%.m: $(VIENNA_DIR)/CurlGetDate/%.m
	$(call prepare_shadow_m)
$(PPC_SRC_DIR)/%.h: $(VIENNA_DIR)/%.h
	$(call prepare_shadow_h)
$(X86_SRC_DIR)/%.m: $(VIENNA_DIR)/%.m
	$(call prepare_shadow_m)
$(X86_SRC_DIR)/%.m: $(VIENNA_DIR)/CurlGetDate/%.m
	$(call prepare_shadow_m)
$(X86_SRC_DIR)/%.h: $(VIENNA_DIR)/%.h
	$(call prepare_shadow_h)

$(INC_DIR)/BacktrackArray.h: $(VIENNA_DIR)/BackTrackArray.h
	@mkdir -p $(dir $@)
	@git -C $(VIENNA_DIR) show HEAD:BackTrackArray.h > $@

$(INC_DIR)/PSMTabBarControl/.dir:
	@mkdir -p $(INC_DIR)/PSMTabBarControl
	@ln -sf $(PSM_DIR)/*.h $(INC_DIR)/PSMTabBarControl/
	@touch $@
