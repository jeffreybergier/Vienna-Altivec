# Standalone Makefile for Vienna 2.2.0 (Mac) - Targeting PPC and i386
# Built for Altivec Intelligence Cross-Compile Environment
#
# Dependency Graph:
#   stage   --> clean
#   debug   --> check --> package --> (BUNDLE)
#   release --> check --> package --> (BUNDLE)
#   patches    (standalone)
#   clean      (standalone)
#   check      (standalone)

APP_NAME = Vienna
JOBS ?= 6

# --- Toolchain ---
export MACOSX_DEPLOYMENT_TARGET = 10.4
SDK    = /osxcross/target/SDK/MacOSX10.5.sdk
CC_PPC = oppc32-gcc
CC_X86 = o32-gcc
LIPO   = i386-apple-darwin9-lipo

ARCH_PPC = -arch ppc  -isysroot $(SDK)
ARCH_X86 = -arch i386 -isysroot $(SDK)

# --- Paths ---
META_DIR = build-stage
SRC_DIR  = $(CURDIR)/src
PSM_DIR  = $(CURDIR)/deps/PSMTabBarControl
CURL_DIR = $(CURDIR)/altivec/libs/libcurl/build-mac

# --- Source File Lists ---
# (1+2) Vienna originals — staged in build-stage/source/ with patches applied
VIENNA_SOURCES = \
  ActivityLog.m \
  ActivityViewer.m \
  AddressBarCell.m \
  AdvancedPreferences.m \
  AppController.m \
  AppearancesPreferences.m \
  ArrayExtensions.m \
  ArticleController.m \
  ArticleFilter.m \
  ArticleListView.m \
  ArticleRef.m \
  ArticleView.m \
  AsyncConnection.m \
  BackTrackArray.m \
  BezierPathExtensions.m \
  BitlyAPIHelper.m \
  BrowserPane.m \
  BrowserPaneTemplate.m \
  BrowserView.m \
  CalendarExtensions.m \
  ClickableProgressIndicator.m \
  Constants.m \
  Criteria.m \
  DSClickableURLTextField.m \
  Database.m \
  DownloadManager.m \
  DownloadWindow.m \
  EmptyTrashWarning.m \
  Export.m \
  ExtDateFormatter.m \
  FeedCredentials.m \
  Field.m \
  FilterView.m \
  Folder.m \
  FolderView.m \
  FoldersTree.m \
  GeneralPreferences.m \
  GradientView.m \
  HelperFunctions.m \
  ImageAndTextCell.m \
  Import.m \
  InfoWindow.m \
  KeyChain.m \
  Message.m \
  MessageListView.m \
  NewGroupFolder.m \
  NewPreferencesController.m \
  NewSubscription.m \
  PluginManager.m \
  PopUpButtonExtensions.m \
  PopupButton.m \
  Preferences.m \
  ProgressTextCell.m \
  RefreshManager.m \
  RenameFolder.m \
  RichXMLParser.m \
  SNDisclosableView.m \
  SNDisclosureButton.m \
  SQLDatabase.m \
  SQLResult.m \
  SQLRow.m \
  SearchFolder.m \
  SearchMethod.m \
  SearchPanel.m \
  SearchString.m \
  SplitViewExtensions.m \
  SquareWindow.m \
  StdEnclosureView.m \
  StringExtensions.m \
  TabbedWebView.m \
  TableViewExtensions.m \
  ThinSplitView.m \
  ToolbarButton.m \
  ToolbarItem.m \
  TreeNode.m \
  URLHandlerCommand.m \
  UnifiedDisplayView.m \
  ViennaApp.m \
  ViewExtensions.m \
  XMLParser.m \
  XMLSourceWindow.m \
  XMLTag.m \
  main.m

# (3+4) External deps — staged in build-stage/deps/ with patches applied
# SQLite and CurlGetDate come from within vienna/; JSONKit from deps/
DEP_SOURCES_C = sqlite/sqlite3.c
DEP_SOURCES_M = JSONKit/JSONKit.m

# (5) Compat — graduated from vienna/ repo; compiled directly from src/compat/
COMPAT_SOURCES = \
  GoogleReader.m \
  SyncPreferences.m

# (7) Custom — authored by us; compiled directly from src/custom/
CUSTOM_SOURCES = \
  CrossPlatform.m \
  stubs.m

# (8) Nibs — custom nib builders; compiled directly from src/nibs/
NIB_SOURCES = \
  SyncPreferences.nib.m

# --- Build Configuration ---
BUILD_DIR ?= build
BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
# debug:   OPT_FLAGS = -O0 -g   (set by `make debug`)
# release: OPT_FLAGS = -O3      (set by `make release`)

# --- Compilation Flags ---
CFLAGS_BASE = $(OPT_FLAGS) \
  -Wall -Wno-import -Wno-trigraphs -fpascal-strings -std=gnu99 \
  -I$(META_DIR)/source \
  -I$(META_DIR)/deps -I$(META_DIR)/deps/JSONKit -I$(META_DIR)/deps/sqlite \
  -I$(SRC_DIR)/compat -I$(SRC_DIR)/custom -I$(SRC_DIR)/nibs \
  -I$(PSM_DIR) \
  -I$(CURL_DIR)/include \
  -F$(META_DIR)/source -F$(META_DIR)/resources -F$(BUILD_DIR)/Frameworks \
  -D"HAVE_USLEEP=1" -D"SQLITE_THREADSAFE=0" \
  -fno-stack-protector -fno-common -fno-zero-initialized-in-bss

# Headers injected into all Objective-C sources via compiler flag.
# deps (JSONKit, sqlite) are compiled without these to avoid conflicts.
OBJC_FLAGS = -fobjc-exceptions \
  -include $(SRC_DIR)/custom/stubs.h \
  -include $(CURDIR)/vienna/Vienna_Prefix.pch \
  -include $(CURDIR)/vienna/HelperFunctions.h \
  -include $(SRC_DIR)/custom/CrossPlatform.h

# --- Linking Flags ---
CURL_LIBS = \
  $(CURL_DIR)/lib/libAICURLConnection.a \
  $(CURL_DIR)/lib/libcurl.a \
  $(CURL_DIR)/lib/libssl.a \
  $(CURL_DIR)/lib/libcrypto.a \
  $(CURL_DIR)/lib/libz.a

LDFLAGS_BASE = \
  -F$(META_DIR)/source -F$(META_DIR)/resources -F$(META_DIR)/deps \
  -F$(BUILD_DIR)/Frameworks \
  -framework AppKit -framework Foundation -framework WebKit \
  -framework Carbon -framework Security -framework IOKit \
  -framework SystemConfiguration -framework ApplicationServices \
  -framework AddressBook \
  $(CURL_LIBS) -lpthread -ldl -lobjc -ObjC -lgcc_s.10.4 \
  -Wl,-no_version_load_command -Wl,-no_function_starts -Wl,-no_data_in_code_info

LDFLAGS_PSM = \
  -framework AppKit -framework Foundation -lobjc -lgcc_s.10.4

.PHONY: clean debug release package stage patches check

check:
	@if [ ! -f "$(CURL_DIR)/lib/libAICURLConnection.a" ]; then \
		echo " [!] ERROR: libcurl not built. Run: docker compose run --rm altivec \"cd /repo/altivec/libs/libcurl && make mac\""; \
		exit 1; \
	fi

stage: clean
	@bash $(SRC_DIR)/scripts/stage.sh

patches:
	@bash $(SRC_DIR)/scripts/generate_patches.sh

debug: check
	@$(MAKE) -j$(JOBS) package BUILD_DIR=build-debug OPT_FLAGS="-O0 -g"
	@echo "--- Debug Build Complete: build-debug/Vienna.app ---"

release: check
	@$(MAKE) -j$(JOBS) package BUILD_DIR=build-release OPT_FLAGS="-O3"
	@echo "--- Release Build Complete: build-release/Vienna.app ---"

# --- Internal Build Logic ---
# The ifeq guard prevents BUILD_DIR-dependent variable expansions from running
# at parse time. Without it, addprefix/addsuffix calls would see the wrong BUILD_DIR.
ifeq ($(filter package,$(MAKECMDGOALS)),package)

  PPC_VIENNA_OBJS = $(addprefix $(BUILD_DIR)/obj/ppc/source/, $(VIENNA_SOURCES:.m=.o))
  X86_VIENNA_OBJS = $(addprefix $(BUILD_DIR)/obj/i386/source/, $(VIENNA_SOURCES:.m=.o))

  PPC_DEP_M_OBJS  = $(addprefix $(BUILD_DIR)/obj/ppc/deps/, $(DEP_SOURCES_M:.m=.o))
  X86_DEP_M_OBJS  = $(addprefix $(BUILD_DIR)/obj/i386/deps/, $(DEP_SOURCES_M:.m=.o))
  PPC_DEP_C_OBJS  = $(addprefix $(BUILD_DIR)/obj/ppc/deps/, $(DEP_SOURCES_C:.c=.o))
  X86_DEP_C_OBJS  = $(addprefix $(BUILD_DIR)/obj/i386/deps/, $(DEP_SOURCES_C:.c=.o))

  PPC_COMPAT_OBJS = $(addprefix $(BUILD_DIR)/obj/ppc/compat/, $(COMPAT_SOURCES:.m=.o))
  X86_COMPAT_OBJS = $(addprefix $(BUILD_DIR)/obj/i386/compat/, $(COMPAT_SOURCES:.m=.o))

  PPC_CUSTOM_OBJS = $(addprefix $(BUILD_DIR)/obj/ppc/custom/, $(CUSTOM_SOURCES:.m=.o))
  X86_CUSTOM_OBJS = $(addprefix $(BUILD_DIR)/obj/i386/custom/, $(CUSTOM_SOURCES:.m=.o))

  PPC_NIB_OBJS    = $(addprefix $(BUILD_DIR)/obj/ppc/nibs/, $(NIB_SOURCES:.m=.o))
  X86_NIB_OBJS    = $(addprefix $(BUILD_DIR)/obj/i386/nibs/, $(NIB_SOURCES:.m=.o))

  PSM_SOURCES  := $(shell ls $(PSM_DIR)/*.m | grep -vE "Inspector|Integration|Plugin|Demo")
  PPC_PSM_OBJS := $(addprefix $(BUILD_DIR)/obj/ppc/psm/, $(notdir $(PSM_SOURCES:.m=.o)))
  X86_PSM_OBJS := $(addprefix $(BUILD_DIR)/obj/i386/psm/, $(notdir $(PSM_SOURCES:.m=.o)))

  PPC_ALL_OBJS = \
    $(PPC_VIENNA_OBJS) $(PPC_DEP_M_OBJS) $(PPC_DEP_C_OBJS) \
    $(PPC_COMPAT_OBJS) $(PPC_CUSTOM_OBJS) $(PPC_NIB_OBJS)
  X86_ALL_OBJS = \
    $(X86_VIENNA_OBJS) $(X86_DEP_M_OBJS) $(X86_DEP_C_OBJS) \
    $(X86_COMPAT_OBJS) $(X86_CUSTOM_OBJS) $(X86_NIB_OBJS)

endif

package: $(BUNDLE)
	@echo " [6/6] Zipping bundle..."
	@cd $(BUILD_DIR) && zip -q -r $(APP_NAME).zip $(APP_NAME).app

clean:
	rm -rf build build-debug build-release build-stage

# --- Linking ---
$(BUNDLE)/Contents/MacOS/$(APP_NAME): $(BUILD_DIR)/ppc.bin $(BUILD_DIR)/i386.bin
	@mkdir -p $(dir $@)
	@echo " [5/6] Merging fat binary..."
	@$(LIPO) -create $^ -output $@

$(BUILD_DIR)/ppc.bin: $(PPC_ALL_OBJS) $(BUILD_DIR)/ppc/PSMTabBarControl.dylib
	@echo " [3/6] Linking ppc slice..."
	@$(CC_PPC) $(ARCH_PPC) $(filter %.o, $^) \
	  $(BUILD_DIR)/ppc/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

$(BUILD_DIR)/i386.bin: $(X86_ALL_OBJS) $(BUILD_DIR)/i386/PSMTabBarControl.dylib
	@echo " [3/6] Linking i386 slice..."
	@$(CC_X86) $(ARCH_X86) $(filter %.o, $^) \
	  $(BUILD_DIR)/i386/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

# --- PSM Framework ---
$(BUNDLE)/Contents/Frameworks/PSMTabBarControl.framework/PSMTabBarControl: \
    $(BUILD_DIR)/ppc/PSMTabBarControl.dylib $(BUILD_DIR)/i386/PSMTabBarControl.dylib
	@mkdir -p $(dir $@)
	@$(LIPO) -create $^ -output $@

$(BUILD_DIR)/ppc/PSMTabBarControl.dylib: $(PPC_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > ppc: linking PSMTabBarControl"
	@$(CC_PPC) -dynamiclib $(ARCH_PPC) \
	  -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
	  $(PPC_PSM_OBJS) $(LDFLAGS_PSM) -o $@

$(BUILD_DIR)/i386/PSMTabBarControl.dylib: $(X86_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > i386: linking PSMTabBarControl"
	@$(CC_X86) -dynamiclib $(ARCH_X86) \
	  -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
	  $(X86_PSM_OBJS) $(LDFLAGS_PSM) -o $@

# --- Object Compilation Rules ---
# Vienna sources (from build-stage/source/ — patches applied during sync)
$(BUILD_DIR)/obj/ppc/source/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/source/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# Dep .m sources — no OBJC_FLAGS to avoid conflicts with third-party code
$(BUILD_DIR)/obj/ppc/deps/%.o: $(META_DIR)/deps/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/deps/%.o: $(META_DIR)/deps/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(ARCH_X86) -c $< -o $@

# Dep .c sources
$(BUILD_DIR)/obj/ppc/deps/%.o: $(META_DIR)/deps/%.c
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/deps/%.o: $(META_DIR)/deps/%.c
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(ARCH_X86) -c $< -o $@

# Compat sources (from src/compat/ — edit directly, no staging needed)
# Compat sources (compiled from build-stage/source/ — copied and patched during staging)
$(BUILD_DIR)/obj/ppc/compat/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/compat/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# Custom sources (from src/custom/ — edit directly, no staging needed)
$(BUILD_DIR)/obj/ppc/custom/%.o: $(SRC_DIR)/custom/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/custom/%.o: $(SRC_DIR)/custom/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# Nib sources (from src/nibs/ — edit directly, no staging needed)
$(BUILD_DIR)/obj/ppc/nibs/%.o: $(SRC_DIR)/nibs/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/nibs/%.o: $(SRC_DIR)/nibs/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# PSM sources (from deps/PSMTabBarControl/ — no staging needed)
$(BUILD_DIR)/obj/ppc/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: psm/$(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(BUILD_DIR)/obj/i386/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: psm/$(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# --- Bundle Assembly ---
$(BUNDLE): \
    $(BUNDLE)/Contents/MacOS/$(APP_NAME) \
    $(BUNDLE)/Contents/Frameworks/PSMTabBarControl.framework/PSMTabBarControl
	@echo " [4/6] Building app bundle..."
	@mkdir -p $(BUNDLE)/Contents/Resources
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Styles
	@mkdir -p $(BUNDLE)/Contents/SharedSupport/Scripts
	@cp $(META_DIR)/Info.plist $(BUNDLE)/Contents/Info.plist
	@echo "APPL????" > $(BUNDLE)/Contents/PkgInfo
	@find $(META_DIR)/resources -maxdepth 1 \
	  \( -name "*.tiff" -o -name "*.plist" -o -name "*.icns" -o -name "*.rtf" \
	  -o -name "*.html" -o -name "*.png" -o -name "*.scriptSuite" \
	  -o -name "*.scriptTerminology" -o -name "*.nib" \) \
	  -exec cp -R {} $(BUNDLE)/Contents/Resources/ \;
	@for dir in $(shell find $(META_DIR)/resources -maxdepth 1 -name "*.lproj" -type d); do \
	  cp -R $$dir $(BUNDLE)/Contents/Resources/; \
	done
	@cp -R $(META_DIR)/resources/Styles/* $(BUNDLE)/Contents/SharedSupport/Styles/
	@cp -R $(META_DIR)/resources/scripts/* $(BUNDLE)/Contents/SharedSupport/Scripts/
	@find $(PSM_DIR) -maxdepth 1 \( -name "*.png" -o -name "*.jpg" \) \
	  -exec cp {} $(BUNDLE)/Contents/Resources/ \;
	@for dir in $(shell find $(PSM_DIR) -maxdepth 1 -name "*.lproj" -type d); do \
	  cp -R $$dir $(BUNDLE)/Contents/Resources/; \
	done
	@echo "  > copying cacert.pem"
	@cp $(CURL_DIR)/lib/cacert.pem $(BUNDLE)/Contents/Resources/
