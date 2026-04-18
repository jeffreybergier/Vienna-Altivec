# Standalone Makefile for Vienna 3.0.8 (Mac) - Targeting PPC and i386
# Built for Altivec Intelligence Cross-Compile Environment
#
# Dependency Graph:
#   stage   --> clean
#   debug   --> check --> package --> (BUNDLE)
#   release --> check --> package --> (BUNDLE)
#   patches    (standalone)
#   clean      (standalone)
#   check      (standalone)

APP_NAME    = Vienna
APP_VERSION = 3.0.8 Altivec
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
META_DIR      = build-stage
SRC_DIR       = $(CURDIR)/src
VIENNA_DIR    = $(CURDIR)/vienna
PSM_DIR       = $(CURDIR)/deps/PSMTabBarControl
CURL_DIR      = $(CURDIR)/altivec/libs/libcurl/build-mac
FMDB_DIR      = $(META_DIR)/deps/FMDB
PXL_DIR       = $(META_DIR)/deps/PXListView
MAS_DIR       = $(META_DIR)/deps/MASPreferences
ASI_DIR       = $(META_DIR)/deps/ASIHTTPRequest
THIRDPARTY_DIR = $(VIENNA_DIR)/3rdparty

# --- Source File Lists ---
# (1) Vienna sources — staged in build-stage/source/ with patches applied
VIENNA_SOURCES = \
  ActivityLog.m \
  ActivityViewer.m \
  AddressBarCell.m \
  AppController.m \
  ArrayExtensions.m \
  ArticleCellView.m \
  ArticleController.m \
  ArticleFilter.m \
  ArticleListView.m \
  ArticleRef.m \
  ArticleView.m \
  BJRWindowWithToolbar.m \
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
  Database.m \
  DownloadManager.m \
  DownloadWindow.m \
  EmptyTrashWarning.m \
  Export.m \
  FeedCredentials.m \
  Field.m \
  FilterView.m \
  Folder.m \
  FolderView.m \
  FoldersTree.m \
  GoogleReader.m \
  GradientView.m \
  HelperFunctions.m \
  ImageAndTextCell.m \
  Import.m \
  InfoWindow.m \
  KeyChain.m \
  MessageListView.m \
  NSNotificationAdditions.m \
  NSURL+Utils.m \
  NewGroupFolder.m \
  NewSubscription.m \
  PluginManager.m \
  PopUpButtonExtensions.m \
  PopupButton.m \
  Preferences.m \
  ProgressTextCell.m \
  RefreshManager.m \
  RenameFolder.m \
  RichXMLParser.m \
  SSTextField.m \
  SearchFolder.m \
  SearchMethod.m \
  SearchPanel.m \
  SearchString.m \
  SplitViewExtensions.m \
  SquareWindow.m \
  StdEnclosureView.m \
  StringExtensions.m \
  SubscriptionModel.m \
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
  models/Article.m \
  Preferences/AdvancedPreferencesViewController.m \
  Preferences/AppearancePreferencesViewController.m \
  Preferences/GeneralPreferencesViewController.m \
  Preferences/SyncingPreferencesViewController.m \
  main.m

# (2) C deps — sqlite from deps/sqlite/ (no longer bundled in vienna/ as of 3.0.8)
DEP_SOURCES_C = sqlite/sqlite3.c

# (3) ObjC deps — JSONKit from deps/JSONKit/
DEP_SOURCES_M = JSONKit/JSONKit.m

# (4) FMDB — from deps/fmdb/src/ (v1.5.2), staged in build-stage/deps/FMDB/
FMDB_SOURCES = \
  FMDatabase.m \
  FMResultSet.m

# (5) PXListView — for UnifiedDisplayView; from vienna/Pods/PXListView/Classes/
PXL_SOURCES = \
  PXListDocumentView.m \
  PXListView+UserInteraction.m \
  PXListView.m \
  PXListViewCell.m

# (6) 3rdparty — from vienna/3rdparty/ subdirs (no staging needed)
THIRDPARTY_SOURCES = \
  BJRVerticallyCenteredTextFieldCell/BJRVerticallyCenteredTextFieldCell.m \
  DSClickableURLTextField/DSClickableURLTextField.m \
  VTPG/VTPG_Common.m

# (7) MASPreferences — staged from vienna/Pods/MASPreferences/, patched for Tiger
MAS_SOURCES = \
  MASPreferencesWindowController.m

# (8) ASIHTTPRequest — staged from vienna/Pods/ASIHTTPRequest/Classes/ (core files, no S3/CloudFiles/WebPage)
ASI_SOURCES = \
  ASIHTTPRequest.m \
  ASIFormDataRequest.m \
  ASINetworkQueue.m \
  ASIInputStream.m \
  ASIDataCompressor.m \
  ASIDataDecompressor.m \
  ASIDownloadCache.m

# (9) Custom — authored by us; compiled directly from src/custom/
CUSTOM_SOURCES = \
  CrossPlatform.m \
  stubs.m

# (10) Nibs — programmatic view builders; compiled from src/nibs/
NIB_SOURCES = \
  GeneralPreferencesView.m \
  AppearancePreferencesView.m \
  SyncingPreferencesView.m \
  AdvancedPreferencesView.m

# --- Build Configuration ---
BUILD_DIR ?= build
INT_DIR    = $(BUILD_DIR)/Intermediates
BUNDLE     = $(BUILD_DIR)/$(APP_NAME).app

# --- Compilation Flags ---
CFLAGS_BASE = $(OPT_FLAGS) \
  -Wall -Wno-import -Wno-trigraphs -fpascal-strings -std=gnu99 \
  -I$(META_DIR)/source \
  -I$(META_DIR)/source/models \
  -I$(META_DIR)/source/Preferences \
  -I$(META_DIR)/deps -I$(META_DIR)/deps/JSONKit -I$(META_DIR)/deps/sqlite \
  -I$(MAS_DIR) \
  -I$(SRC_DIR)/custom \
  -I$(PSM_DIR) \
  -I$(CURDIR)/deps \
  -I$(ASI_DIR) \
  -I$(FMDB_DIR) \
  -I$(PXL_DIR) \
  -I$(THIRDPARTY_DIR)/BJRVerticallyCenteredTextFieldCell \
  -I$(THIRDPARTY_DIR)/DSClickableURLTextField \
  -I$(THIRDPARTY_DIR)/VTPG \
  -I$(CURL_DIR)/include \
  -F$(META_DIR)/resources \
  -D"HAVE_USLEEP=1" -D"SQLITE_THREADSAFE=0" -D"SQLITE_WITHOUT_ZONEMALLOC=1" \
  -fno-stack-protector -fno-common -fno-zero-initialized-in-bss

# Headers injected into all Objective-C sources via compiler flag.
# deps (JSONKit, sqlite, FMDB, PXListView) are compiled without these.
OBJC_FLAGS = -fobjc-exceptions \
  -include $(SRC_DIR)/custom/stubs.h \
  -include $(VIENNA_DIR)/src/Vienna_Prefix.pch \
  -include $(VIENNA_DIR)/src/HelperFunctions.h \
  -include $(SRC_DIR)/custom/CrossPlatform.h

# --- Linking Flags ---
# ASIHTTPRequest: patched to use libcurl (replaces CFNetwork streaming).
# CFNetwork framework is still linked for auth/proxy data-structure APIs.
CURL_LIBS = \
  $(CURL_DIR)/lib/libcurl.a \
  $(CURL_DIR)/lib/libssl.a \
  $(CURL_DIR)/lib/libcrypto.a \
  $(CURL_DIR)/lib/libz.a

LDFLAGS_BASE = \
  -F$(META_DIR)/resources \
  -framework AppKit -framework Foundation -framework WebKit \
  -framework Carbon -framework CoreServices -framework Security -framework IOKit \
  -framework SystemConfiguration -framework ApplicationServices \
  -framework AddressBook \
  $(CURL_LIBS) -lpthread -ldl -lobjc -ObjC -lgcc_s.10.4 \
  -Wl,-flat_namespace \
  -Wl,-no_version_load_command -Wl,-no_function_starts -Wl,-no_data_in_code_info

LDFLAGS_PSM = \
  -framework AppKit -framework Foundation -lobjc -lgcc_s.10.4 \
  -Wl,-flat_namespace

.PHONY: clean debug release package stage patches check

check:
	@if [ ! -f "$(META_DIR)/deps/sqlite/sqlite3.c" ]; then \
		echo " [!] ERROR: sqlite not staged. Run: make stage"; \
		exit 1; \
	fi
	@if [ ! -f "$(ASI_DIR)/ASIHTTPRequest.m" ]; then \
		echo " [!] ERROR: ASIHTTPRequest not staged. Run: make stage"; \
		exit 1; \
	fi

stage: clean
	@rm -rf build-stage
	@bash $(SRC_DIR)/scripts/stage.sh

patches:
	@bash $(SRC_DIR)/scripts/generate_patches.sh

debug:
	@if [ ! -f "$(META_DIR)/.stamp" ]; then bash $(SRC_DIR)/scripts/stage.sh; fi
	@$(MAKE) check
	@$(MAKE) -j$(JOBS) package BUILD_DIR=build-debug OPT_FLAGS="-O0 -g"
	@echo "--- Debug Build Complete: build-debug/Vienna.app ---"

release: check
	@$(MAKE) -j$(JOBS) package BUILD_DIR=build-release OPT_FLAGS="-O3"
	@echo "--- Release Build Complete: build-release/Vienna.app ---"

# --- Internal Build Logic ---
ifeq ($(filter package,$(MAKECMDGOALS)),package)

  PPC_VIENNA_OBJS  = $(addprefix $(INT_DIR)/obj/ppc/source/, $(VIENNA_SOURCES:.m=.o))
  X86_VIENNA_OBJS  = $(addprefix $(INT_DIR)/obj/i386/source/, $(VIENNA_SOURCES:.m=.o))

  PPC_DEP_M_OBJS   = $(addprefix $(INT_DIR)/obj/ppc/deps/, $(DEP_SOURCES_M:.m=.o))
  X86_DEP_M_OBJS   = $(addprefix $(INT_DIR)/obj/i386/deps/, $(DEP_SOURCES_M:.m=.o))
  PPC_DEP_C_OBJS   = $(addprefix $(INT_DIR)/obj/ppc/deps/, $(DEP_SOURCES_C:.c=.o))
  X86_DEP_C_OBJS   = $(addprefix $(INT_DIR)/obj/i386/deps/, $(DEP_SOURCES_C:.c=.o))

  PPC_FMDB_OBJS    = $(addprefix $(INT_DIR)/obj/ppc/fmdb/, $(FMDB_SOURCES:.m=.o))
  X86_FMDB_OBJS    = $(addprefix $(INT_DIR)/obj/i386/fmdb/, $(FMDB_SOURCES:.m=.o))

  PPC_PXL_OBJS     = $(addprefix $(INT_DIR)/obj/ppc/pxl/, $(PXL_SOURCES:.m=.o))
  X86_PXL_OBJS     = $(addprefix $(INT_DIR)/obj/i386/pxl/, $(PXL_SOURCES:.m=.o))

  PPC_3RD_OBJS     = $(addprefix $(INT_DIR)/obj/ppc/3rdparty/, $(THIRDPARTY_SOURCES:.m=.o))
  X86_3RD_OBJS     = $(addprefix $(INT_DIR)/obj/i386/3rdparty/, $(THIRDPARTY_SOURCES:.m=.o))

  PPC_CUSTOM_OBJS  = $(addprefix $(INT_DIR)/obj/ppc/custom/, $(CUSTOM_SOURCES:.m=.o))
  X86_CUSTOM_OBJS  = $(addprefix $(INT_DIR)/obj/i386/custom/, $(CUSTOM_SOURCES:.m=.o))

  PPC_NIB_OBJS     = $(addprefix $(INT_DIR)/obj/ppc/nibs/, $(NIB_SOURCES:.m=.o))
  X86_NIB_OBJS     = $(addprefix $(INT_DIR)/obj/i386/nibs/, $(NIB_SOURCES:.m=.o))

  PPC_MAS_OBJS     = $(addprefix $(INT_DIR)/obj/ppc/mas/, $(MAS_SOURCES:.m=.o))
  X86_MAS_OBJS     = $(addprefix $(INT_DIR)/obj/i386/mas/, $(MAS_SOURCES:.m=.o))

  PPC_ASI_OBJS     = $(addprefix $(INT_DIR)/obj/ppc/asi/, $(ASI_SOURCES:.m=.o))
  X86_ASI_OBJS     = $(addprefix $(INT_DIR)/obj/i386/asi/, $(ASI_SOURCES:.m=.o))

  PSM_SOURCES  := $(shell ls $(PSM_DIR)/*.m | grep -vE "Inspector|Integration|Plugin|Demo")
  PPC_PSM_OBJS := $(addprefix $(INT_DIR)/obj/ppc/psm/, $(notdir $(PSM_SOURCES:.m=.o)))
  X86_PSM_OBJS := $(addprefix $(INT_DIR)/obj/i386/psm/, $(notdir $(PSM_SOURCES:.m=.o)))

  PPC_ALL_OBJS = \
    $(PPC_VIENNA_OBJS) $(PPC_DEP_M_OBJS) $(PPC_DEP_C_OBJS) \
    $(PPC_FMDB_OBJS) $(PPC_PXL_OBJS) $(PPC_3RD_OBJS) \
    $(PPC_MAS_OBJS) $(PPC_ASI_OBJS) $(PPC_CUSTOM_OBJS) $(PPC_NIB_OBJS)
  X86_ALL_OBJS = \
    $(X86_VIENNA_OBJS) $(X86_DEP_M_OBJS) $(X86_DEP_C_OBJS) \
    $(X86_FMDB_OBJS) $(X86_PXL_OBJS) $(X86_3RD_OBJS) \
    $(X86_MAS_OBJS) $(X86_ASI_OBJS) $(X86_CUSTOM_OBJS) $(X86_NIB_OBJS)

endif

package: $(BUNDLE)
	@echo " [6/6] Zipping bundle..."
	@cd $(BUILD_DIR) && zip -q -r $(APP_NAME).zip $(APP_NAME).app

clean:
	rm -rf build-stage build-debug build-release

# --- Linking ---
$(BUNDLE)/Contents/MacOS/$(APP_NAME): $(INT_DIR)/ppc.bin $(INT_DIR)/i386.bin
	@mkdir -p $(dir $@)
	@echo " [5/6] Merging fat binary..."
	@$(LIPO) -create $^ -output $@

$(INT_DIR)/ppc.bin: $(PPC_ALL_OBJS) $(INT_DIR)/ppc/PSMTabBarControl.dylib
	@echo " [3/6] Linking ppc slice..."
	@$(CC_PPC) $(ARCH_PPC) $(filter %.o, $^) \
	  $(INT_DIR)/ppc/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

$(INT_DIR)/i386.bin: $(X86_ALL_OBJS) $(INT_DIR)/i386/PSMTabBarControl.dylib
	@echo " [3/6] Linking i386 slice..."
	@$(CC_X86) $(ARCH_X86) $(filter %.o, $^) \
	  $(INT_DIR)/i386/PSMTabBarControl.dylib $(LDFLAGS_BASE) -o $@

# --- PSM Framework ---
$(BUNDLE)/Contents/Frameworks/PSMTabBarControl.framework/PSMTabBarControl: \
    $(INT_DIR)/ppc/PSMTabBarControl.dylib $(INT_DIR)/i386/PSMTabBarControl.dylib
	@mkdir -p $(dir $@)
	@$(LIPO) -create $^ -output $@

$(INT_DIR)/ppc/PSMTabBarControl.dylib: $(PPC_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > ppc: linking PSMTabBarControl"
	@$(CC_PPC) -dynamiclib $(ARCH_PPC) \
	  -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
	  $(PPC_PSM_OBJS) $(LDFLAGS_PSM) -o $@

$(INT_DIR)/i386/PSMTabBarControl.dylib: $(X86_PSM_OBJS)
	@mkdir -p $(dir $@)
	@echo "  > i386: linking PSMTabBarControl"
	@$(CC_X86) -dynamiclib $(ARCH_X86) \
	  -install_name @executable_path/../Frameworks/PSMTabBarControl.framework/PSMTabBarControl \
	  $(X86_PSM_OBJS) $(LDFLAGS_PSM) -o $@

# --- Object Compilation Rules ---

# Vienna sources (from build-stage/source/)
$(INT_DIR)/obj/ppc/source/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/source/%.o: $(META_DIR)/source/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# Dep .m sources (no OBJC_FLAGS — third-party)
$(INT_DIR)/obj/ppc/deps/%.o: $(META_DIR)/deps/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/deps/%.o: $(META_DIR)/deps/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(ARCH_X86) -c $< -o $@

# Dep .c sources
$(INT_DIR)/obj/ppc/deps/%.o: $(META_DIR)/deps/%.c
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/deps/%.o: $(META_DIR)/deps/%.c
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(ARCH_X86) -c $< -o $@

# FMDB sources (from deps/fmdb/src/ — no OBJC_FLAGS, warnings suppressed)
$(INT_DIR)/obj/ppc/fmdb/%.o: $(FMDB_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(ARCH_PPC) -w -c $< -o $@

$(INT_DIR)/obj/i386/fmdb/%.o: $(FMDB_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(ARCH_X86) -w -c $< -o $@

# PXListView sources (from vienna/Pods/PXListView/Classes/ — inject Foundation)
$(INT_DIR)/obj/ppc/pxl/%.o: $(PXL_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) -include $(SRC_DIR)/custom/stubs.h $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/pxl/%.o: $(PXL_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) -include $(SRC_DIR)/custom/stubs.h $(ARCH_X86) -c $< -o $@

# 3rdparty sources (from vienna/3rdparty/ — inject Foundation via stubs.h)
$(INT_DIR)/obj/ppc/3rdparty/%.o: $(THIRDPARTY_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) -include $(SRC_DIR)/custom/stubs.h $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/3rdparty/%.o: $(THIRDPARTY_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) -include $(SRC_DIR)/custom/stubs.h $(ARCH_X86) -c $< -o $@

# MASPreferences sources (staged from vienna/Pods/MASPreferences/, patched)
$(INT_DIR)/obj/ppc/mas/%.o: $(MAS_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: mas/$(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/mas/%.o: $(MAS_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: mas/$(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# ASIHTTPRequest sources (staged from vienna/Pods/ASIHTTPRequest/Classes/ — warnings suppressed, exceptions enabled)
$(INT_DIR)/obj/ppc/asi/%.o: $(ASI_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: asi/$(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) -fobjc-exceptions \
	  -include $(SRC_DIR)/custom/stubs.h \
	  -include $(SRC_DIR)/custom/CrossPlatform.h \
	  -w $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/asi/%.o: $(ASI_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: asi/$(<F)"
	@$(CC_X86) $(CFLAGS_BASE) -fobjc-exceptions \
	  -include $(SRC_DIR)/custom/stubs.h \
	  -include $(SRC_DIR)/custom/CrossPlatform.h \
	  -w $(ARCH_X86) -c $< -o $@

# Custom sources (from src/custom/)
$(INT_DIR)/obj/ppc/custom/%.o: $(SRC_DIR)/custom/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: $(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/custom/%.o: $(SRC_DIR)/custom/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: $(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# Nib sources (from src/nibs/)
$(INT_DIR)/obj/ppc/nibs/%.o: $(SRC_DIR)/nibs/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: nibs/$(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/nibs/%.o: $(SRC_DIR)/nibs/%.m
	@mkdir -p $(dir $@)
	@echo "  > i386: nibs/$(<F)"
	@$(CC_X86) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_X86) -c $< -o $@

# PSM sources (from deps/PSMTabBarControl/)
$(INT_DIR)/obj/ppc/psm/%.o: $(PSM_DIR)/%.m
	@mkdir -p $(dir $@)
	@echo "  > ppc: psm/$(<F)"
	@$(CC_PPC) $(CFLAGS_BASE) $(OBJC_FLAGS) $(ARCH_PPC) -c $< -o $@

$(INT_DIR)/obj/i386/psm/%.o: $(PSM_DIR)/%.m
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
	@sed -e 's/VCS_TAG :VCS_SHORT_HASH:/$(APP_VERSION)/g' \
	     -e 's/VCS_TAG/$(APP_VERSION)/g' \
	     -e 's/VCS_SHORT_HASH/$(APP_VERSION)/g' \
	     -e 's/VCS_NUM/1/g' \
	     -e 's/VCS_FULL_HASH/$(APP_VERSION)/g' \
	     $(META_DIR)/Info.plist > $(BUNDLE)/Contents/Info.plist
	@echo "APPL????" > $(BUNDLE)/Contents/PkgInfo
	# Static resources (tiff, plist, icns, etc.)
	@find $(META_DIR)/resources -maxdepth 1 \
	  \( -name "*.tiff" -o -name "*.plist" -o -name "*.icns" -o -name "*.rtf" \
	  -o -name "*.html" -o -name "*.png" -o -name "*.scriptSuite" \
	  -o -name "*.scriptTerminology" \) \
	  -exec cp -R {} $(BUNDLE)/Contents/Resources/ \;
	# Pre-compiled NIBs from vienna/Interfaces/
	@find $(META_DIR)/resources -maxdepth 1 -name "*.nib" -type d \
	  -exec cp -R {} $(BUNDLE)/Contents/Resources/ \;
	# lproj bundles
	@for dir in $(shell find $(META_DIR)/resources -maxdepth 1 -name "*.lproj" -type d); do \
	  cp -R $$dir $(BUNDLE)/Contents/Resources/; \
	done
	@cp -R $(META_DIR)/resources/Styles/* $(BUNDLE)/Contents/SharedSupport/Styles/ 2>/dev/null || true
	@if [ -d $(META_DIR)/resources/scripts ]; then \
	  cp -R $(META_DIR)/resources/scripts/* $(BUNDLE)/Contents/SharedSupport/Scripts/ 2>/dev/null || true; \
	fi
	@find $(PSM_DIR) -maxdepth 1 \( -name "*.png" -o -name "*.jpg" \) \
	  -exec cp {} $(BUNDLE)/Contents/Resources/ \;
	@for dir in $(shell find $(PSM_DIR) -maxdepth 1 -name "*.lproj" -type d); do \
	  cp -R $$dir $(BUNDLE)/Contents/Resources/; \
	done
	@echo "  > copying cacert.pem (optional)"
	@cp $(CURL_DIR)/lib/cacert.pem $(BUNDLE)/Contents/Resources/ 2>/dev/null || true
