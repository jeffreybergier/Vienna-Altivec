# Standalone Makefile for Vienna 2.2.0 (Mac) - Targeting PPC and i386
# Built for Altivec Intelligence Cross-Compile Environment

APP_NAME = Vienna
PPC_SDK = /osxcross/target/SDK/MacOSX10.5.sdk
i386_SDK = /osxcross/target/SDK/MacOSX10.5.sdk

CC_PPC = oppc32-gcc
CC_X86 = o32-gcc
LIPO = i386-apple-darwin9-lipo

# --- Build Configuration ---
BUILD_DIR ?= build
BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
OPT_FLAGS ?= -O2

# Paths
META_DIR = build-meta
STUBS_H = $(CURDIR)/source/stubs.h
STUBS_M = $(CURDIR)/source/stubs.m
PSM_DIR = $(CURDIR)/deps/PSMTabBarControl
CURL_DIR = $(CURDIR)/altivec/libs/libcurl/build-mac

# Compilation Flags
CFLAGS_BASE = $(OPT_FLAGS) -g -Wall -Wno-import -Wno-trigraphs -fpascal-strings -std=gnu99 \
              -I$(META_DIR) -I$(META_DIR)/sqlite -I$(META_DIR)/extra -I$(PSM_DIR) \
              -I$(CURL_DIR)/include \
              -F$(META_DIR) -F$(BUILD_DIR)/Frameworks \
              -D"HAVE_USLEEP=1" -D"SQLITE_THREADSAFE=0" \
              -fno-stack-protector -fno-common -fno-zero-initialized-in-bss

OBJC_FLAGS = -fobjc-exceptions -include $(STUBS_H)

# Linking Flags
CURL_LIBS = $(CURL_DIR)/lib/libAICURLConnection.a $(CURL_DIR)/lib/libcurl.a \
            $(CURL_DIR)/lib/libssl.a $(CURL_DIR)/lib/libcrypto.a $(CURL_DIR)/lib/libz.a
LDFLAGS_BASE = -F$(META_DIR) -F$(BUILD_DIR)/Frameworks -framework AppKit -framework Foundation -framework WebKit \
               -framework Carbon -framework Security -framework IOKit \
               -framework SystemConfiguration -framework ApplicationServices -framework AddressBook \
               $(CURL_LIBS) -lpthread -ldl -lobjc -ObjC -lgcc_s.10.4 \
               -Wl,-no_version_load_command -Wl,-no_function_starts -Wl,-no_data_in_code_info

.PHONY: all clean debug release build_internal sync_meta print_vars patches validate_curl

all: release

validate_curl:
	@if [ ! -f "$(CURL_DIR)/lib/libAICURLConnection.a" ]; then \
		echo " [!] ERROR: libcurl not built. Run: docker compose run --rm altivec \"cd /repo/altivec/libs/libcurl && make mac\""; \
		exit 1; \
	fi

sync_meta:
	@bash $(CURDIR)/source/sync_meta.sh

patches:
	@bash $(CURDIR)/source/generate_patches.sh

debug: validate_curl
	@$(MAKE) sync_meta
	@$(MAKE) build_internal BUILD_DIR=build-debug OPT_FLAGS="-O0"
	@echo "--- Debug Build Complete: build-debug/Vienna.app ---"

release: validate_curl
	@$(MAKE) sync_meta
	@$(MAKE) build_internal BUILD_DIR=build-release OPT_FLAGS="-O3"
	@echo "--- Release Build Complete: build-release/Vienna.app ---"

# --- Internal Build Logic ---

# We only calculate these when build_internal is actually running
# and after sync_meta has definitely finished.
ifeq ($(filter build_internal,$(MAKECMDGOALS)),build_internal)
  # Vienna sources
  SOURCES_M := $(wildcard $(META_DIR)/*.m) $(wildcard $(META_DIR)/extra/*.m)
  SOURCES_C := $(wildcard $(META_DIR)/sqlite/*.c)
  
  # PSM sources
  PSM_SOURCES := $(shell ls $(PSM_DIR)/*.m | grep -vE "Inspector|Integration|Plugin|Demo")
  
  # Flat object mapping
  OBJS_BASE := $(notdir $(SOURCES_M:.m=.o) $(SOURCES_C:.c=.o)) stubs.o
  
  PPC_OBJS := $(addprefix $(BUILD_DIR)/obj/ppc/, $(OBJS_BASE))
  X86_OBJS := $(addprefix $(BUILD_DIR)/obj/i386/, $(OBJS_BASE))
  
  PSM_OBJS_BASE := $(notdir $(PSM_SOURCES:.m=.o))
  PPC_PSM_OBJS := $(addprefix $(BUILD_DIR)/obj/ppc/psm/, $(PSM_OBJS_BASE))
  X86_PSM_OBJS := $(addprefix $(BUILD_DIR)/obj/i386/psm/, $(PSM_OBJS_BASE))
endif

build_internal: $(BUNDLE)
	@echo " [6/6] Zipping bundle..."
	@cd $(BUILD_DIR) && zip -q -r $(APP_NAME).zip $(APP_NAME).app

clean:
	rm -rf build build-debug build-release build-meta build-meta-tmp

# Linking
$(BUNDLE)/Contents/MacOS/$(APP_NAME): $(BUILD_DIR)/ppc.bin $(BUILD_DIR)/i386.bin
	@mkdir -p $(dir $@)
	@echo " [5/6] Merging fat binary..."
	@$(LIPO) -create $^ -output $@

$(BUILD_DIR)/ppc.bin: $(PPC_OBJS) $(BUILD_DIR)/ppc/PSMTabBarControl.dylib
	@echo " [3/6] Linking ppc slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) -arch ppc -isysroot $(PPC_SDK) $(filter %.o, $^) $(BUILD_DIR)/ppc/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

$(BUILD_DIR)/i386.bin: $(X86_OBJS) $(BUILD_DIR)/i386/PSMTabBarControl.dylib
	@echo " [3/6] Linking i386 slice..."
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) -arch i386 -isysroot $(i386_SDK) $(filter %.o, $^) $(BUILD_DIR)/i386/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

# PSM Framework
$(BUNDLE)/Contents/Frameworks/PSMTabBarControl.framework/PSMTabBarControl: $(BUILD_DIR)/ppc/PSMTabBarControl.dylib $(BUILD_DIR)/i386/PSMTabBarControl.dylib
	@mkdir -p $(dir $@)
	@$(LIPO) -create $^ -output $@

$(BUILD_DIR)/ppc/PSMTabBarControl.dylib: $(PPC_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > ppc: linking PSMTabBarControl"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) -dynamiclib -arch ppc -isysroot $(PPC_SDK) -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl $(PPC_PSM_OBJS) -framework AppKit -framework Foundation -lobjc -lgcc_s.10.4 -o $@

$(BUILD_DIR)/i386/PSMTabBarControl.dylib: $(X86_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > i386: linking PSMTabBarControl"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) -dynamiclib -arch i386 -isysroot $(i386_SDK) -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl $(X86_PSM_OBJS) -framework AppKit -framework Foundation -lobjc -lgcc_s.10.4 -o $@

# Object rules using VPATH-like behavior (manual lookup)
# We search in multiple dirs for the .m/.c file
$(BUILD_DIR)/obj/ppc/%.o:
	@mkdir -p $(dir $@)
	@file=$$(find $(META_DIR) -name "$*.m" -o -name "$*.c" | head -n 1); \
	 echo "  > ppc: $$(basename $$file)"; \
	 MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) -arch ppc -isysroot $(PPC_SDK) -c $$file -o $@

$(BUILD_DIR)/obj/i386/%.o:
	@mkdir -p $(dir $@)
	@file=$$(find $(META_DIR) -name "$*.m" -o -name "$*.c" | head -n 1); \
	 echo "  > i386: $$(basename $$file)"; \
	 MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) -arch i386 -isysroot $(i386_SDK) -c $$file -o $@

# Special rules for stubs and PSM which are outside build-meta
$(BUILD_DIR)/obj/%/stubs.o: $(STUBS_M)
	@mkdir -p $(dir $@)
	@echo "  > $*: stubs.m"
	@if [ "$*" = "ppc" ]; then \
		MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) -x objective-c -arch ppc -isysroot $(PPC_SDK) -c $< -o $@; \
	else \
		MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) -arch i386 -isysroot $(i386_SDK) -c $< -o $@; \
	fi

$(BUILD_DIR)/obj/ppc/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: psm/$(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) -arch ppc -isysroot $(PPC_SDK) -c $< -o $@

$(BUILD_DIR)/obj/i386/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: psm/$(notdir $<)"
	@MACOSX_DEPLOYMENT_TARGET=10.4 $(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) -arch i386 -isysroot $(i386_SDK) -c $< -o $@

# Bundle Resources
$(BUNDLE): $(BUNDLE)/Contents/MacOS/$(APP_NAME) $(BUNDLE)/Contents/Frameworks/PSMTabBarControl.framework/PSMTabBarControl
	@echo " [4/6] Building app bundle..."
	@mkdir -p $(BUNDLE)/Contents/Resources
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Styles
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Scripts
	@cp $(META_DIR)/Info.plist $(BUNDLE)/Contents/Info.plist
	@echo "APPL????" > $(BUNDLE)/Contents/PkgInfo
	@find $(META_DIR) -maxdepth 1 \( -name "*.tiff" -o -name "*.plist" -o -name "*.icns" -o -name "*.rtf" -o -name "*.html" -o -name "*.png" -o -name "*.scriptSuite" -o -name "*.scriptTerminology" -o -name "*.nib" \) -exec cp -R {} $(BUNDLE)/Contents/Resources/ \;
	@for dir in $(shell find $(META_DIR) -maxdepth 1 -name "*.lproj" -type d); do cp -R $$dir $(BUNDLE)/Contents/Resources/; done
	@cp -R $(META_DIR)/Styles/* $(BUNDLE)/Contents/SharedSupport/Styles/
	@cp -R $(META_DIR)/scripts/* $(BUNDLE)/Contents/SharedSupport/Scripts/
	@find $(PSM_DIR) -maxdepth 1 \( -name "*.png" -o -name "*.jpg" \) -exec cp {} $(BUNDLE)/Contents/Resources/ \;
	@for dir in $(shell find $(PSM_DIR) -maxdepth 1 -name "*.lproj" -type d); do cp -R $$dir $(BUNDLE)/Contents/Resources/; done
	@echo "  > copying cacert.pem"
	@cp $(CURL_DIR)/lib/cacert.pem $(BUNDLE)/Contents/Resources/
