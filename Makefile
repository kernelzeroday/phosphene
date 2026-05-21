# Phosphene — custom build system
# Targets macOS 26 (Tahoe), Apple Silicon
# No Xcode required. Uses swiftc from Command Line Tools.

TARGET    ?= arm64-apple-macosx26.0
SDK       ?= /Library/Developer/CommandLineTools/SDKs/MacOSX26.0.sdk
SWIFT     ?= swiftc
CODESIGN  ?= codesign
BUILD     ?= build

IDENTIFIER  = dev.phosphene
TEAM        = 52K336H235

APP_NAME    = Phosphene
EXT_NAME    = PhospheneExtension

APP_BUNDLE  = $(BUILD)/$(APP_NAME).app
EXT_BUNDLE  = $(APP_BUNDLE)/Contents/Extensions/$(EXT_NAME).appex

APP_EXEC    = $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
EXT_EXEC    = $(EXT_BUNDLE)/Contents/MacOS/$(EXT_NAME)

APP_DIR     = $(APP_NAME)
EXT_DIR     = $(EXT_NAME)

APP_SRCS    = $(wildcard $(APP_DIR)/*.swift)
EXT_SRCS    = $(wildcard $(EXT_DIR)/*.swift)
EXT_C_SRCS  = $(wildcard $(EXT_DIR)/*.c) $(wildcard $(EXT_DIR)/*.m)

SWIFT_FLAGS = \
	-target $(TARGET) \
	-sdk $(SDK) \
	-swift-version 6 \
	-warnings-as-errors \
	-enable-upcoming-feature ExistentialAny \
	-enable-upcoming-feature MemberImportVisibility \
	-enable-upcoming-feature NonIsolatedNonsendingByDefault \
	-O

# Default: build the app bundle
all: $(APP_BUNDLE)

# ============================================================
# PHOSPHENE EXTENSION (.appex embedded in app bundle)
# ============================================================

$(EXT_EXEC): $(EXT_SRCS) $(EXT_C_SRCS)
	@mkdir -p $(EXT_BUNDLE)/Contents/MacOS $(EXT_BUNDLE)/Contents/Resources
	$(SWIFT) $(SWIFT_FLAGS) \
		-module-name $(EXT_NAME) \
		-import-objc-header $(EXT_DIR)/WallpaperExtension-Bridging-Header.h \
		-I Modules \
		-F /System/Library/PrivateFrameworks \
		-framework ExtensionFoundation \
		-framework WallpaperExtensionKit \
		-framework WallpaperFoundation \
		-framework Wallpaper \
		-framework WallpaperTypes \
		-o $@ \
		$(EXT_SRCS) $(EXT_C_SRCS)

$(EXT_BUNDLE)/Contents/Info.plist: $(EXT_EXEC)
	@mkdir -p $(@D)
	( \
	  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	  echo '<plist version="1.0">'; \
	  echo '<dict>'; \
	  echo '	<key>CFBundleDevelopmentRegion</key>'; \
	  echo '	<string>en</string>'; \
	  echo '	<key>CFBundleDisplayName</key>'; \
	  echo '	<string>PhospheneWallpaperExtension</string>'; \
	  echo '	<key>CFBundleExecutable</key>'; \
	  echo '	<string>$(EXT_NAME)</string>'; \
	  echo '	<key>CFBundleIdentifier</key>'; \
	  echo '	<string>$(IDENTIFIER).extension</string>'; \
	  echo '	<key>CFBundleInfoDictionaryVersion</key>'; \
	  echo '	<string>6.0</string>'; \
	  echo '	<key>CFBundleName</key>'; \
	  echo '	<string>$(EXT_NAME)</string>'; \
	  echo '	<key>CFBundlePackageType</key>'; \
	  echo '	<string>XPC!</string>'; \
	  echo '	<key>CFBundleShortVersionString</key>'; \
	  echo '	<string>1.0</string>'; \
	  echo '	<key>CFBundleVersion</key>'; \
	  echo '	<string>1</string>'; \
	  echo '	<key>LSMinimumSystemVersion</key>'; \
	  echo '	<string>26.0</string>'; \
	  echo '	<key>EXAppExtensionAttributes</key>'; \
	  echo '	<dict>'; \
	  echo '		<key>EXExtensionPointIdentifier</key>'; \
	  echo '		<string>com.apple.wallpaper</string>'; \
	  echo '	</dict>'; \
	  echo '	<key>NSExtension</key>'; \
	  echo '	<dict>'; \
	  echo '		<key>NSExtensionPointIdentifier</key>'; \
	  echo '		<string>com.apple.wallpaper</string>'; \
	  echo '		<key>NSExtensionPrincipalClass</key>'; \
	  echo '		<string>PhospheneExtension.PhospheneWallpaper</string>'; \
	  echo '	</dict>'; \
	  echo '</dict>'; \
	  echo '</plist>'; \
	) > $@

# Phony intermediate to ensure extension bundle is complete
$(EXT_BUNDLE): $(EXT_BUNDLE)/Contents/Info.plist
	@true

# ============================================================
# PHOSPHENE APP
# ============================================================

$(APP_EXEC): $(APP_SRCS)
	@mkdir -p $(APP_BUNDLE)/Contents/MacOS $(APP_BUNDLE)/Contents/Resources
	$(SWIFT) $(SWIFT_FLAGS) \
		-module-name $(APP_NAME) \
		-o $@ \
		$(APP_SRCS)

$(APP_BUNDLE)/Contents/Info.plist: $(APP_EXEC)
	@mkdir -p $(@D)
	( \
	  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	  echo '<plist version="1.0">'; \
	  echo '<dict>'; \
	  echo '	<key>CFBundleDevelopmentRegion</key>'; \
	  echo '	<string>en</string>'; \
	  echo '	<key>CFBundleDisplayName</key>'; \
	  echo '	<string>Phosphene</string>'; \
	  echo '	<key>CFBundleExecutable</key>'; \
	  echo '	<string>$(APP_NAME)</string>'; \
	  echo '	<key>CFBundleIdentifier</key>'; \
	  echo '	<string>$(IDENTIFIER)</string>'; \
	  echo '	<key>CFBundleInfoDictionaryVersion</key>'; \
	  echo '	<string>6.0</string>'; \
	  echo '	<key>CFBundleName</key>'; \
	  echo '	<string>Phosphene</string>'; \
	  echo '	<key>CFBundlePackageType</key>'; \
	  echo '	<string>APPL</string>'; \
	  echo '	<key>CFBundleShortVersionString</key>'; \
	  echo '	<string>1.0</string>'; \
	  echo '	<key>CFBundleVersion</key>'; \
	  echo '	<string>1</string>'; \
	  echo '	<key>LSMinimumSystemVersion</key>'; \
	  echo '	<string>26.0</string>'; \
	  echo '	<key>CFBundleURLTypes</key>'; \
	  echo '	<array>'; \
	  echo '		<dict>'; \
	  echo '			<key>CFBundleURLName</key>'; \
	  echo '			<string>$(IDENTIFIER)</string>'; \
	  echo '			<key>CFBundleURLSchemes</key>'; \
	  echo '			<array>'; \
	  echo '				<string>phosphene</string>'; \
	  echo '			</array>'; \
	  echo '		</dict>'; \
	  echo '	</array>'; \
	  echo '</dict>'; \
	  echo '</plist>'; \
	) > $@

# ============================================================
# APP BUNDLE (embed extension, sign)
# ============================================================

# Extension entitlements (sandbox + app groups)
EXT_ENTITLEMENTS = $(BUILD)/PhospheneExtension.entitlements
$(EXT_ENTITLEMENTS): | $(BUILD)
	( \
	  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	  echo '<plist version="1.0">'; \
	  echo '<dict>'; \
	  echo '	<key>com.apple.security.app-sandbox</key>'; \
	  echo '	<true/>'; \
	  echo '	<key>com.apple.security.cs.disable-library-validation</key>'; \
	  echo '	<true/>'; \
	  echo '	<key>com.apple.security.application-groups</key>'; \
	  echo '	<array>'; \
	  echo '		<string>$(IDENTIFIER)</string>'; \
	  echo '	</array>'; \
	  echo '</dict>'; \
	  echo '</plist>'; \
	) > $@

# App entitlements (bookmarks + app groups)
APP_ENTITLEMENTS = $(BUILD)/Phosphene.entitlements
$(APP_ENTITLEMENTS): | $(BUILD)
	( \
	  echo '<?xml version="1.0" encoding="UTF-8"?>'; \
	  echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
	  echo '<plist version="1.0">'; \
	  echo '<dict>'; \
	  echo '	<key>com.apple.security.files.bookmarks.app-scope</key>'; \
	  echo '	<true/>'; \
	  echo '	<key>com.apple.security.application-groups</key>'; \
	  echo '	<array>'; \
	  echo '		<string>$(IDENTIFIER)</string>'; \
	  echo '	</array>'; \
	  echo '</dict>'; \
	  echo '</plist>'; \
	) > $@

$(APP_BUNDLE): $(APP_BUNDLE)/Contents/Info.plist $(EXT_BUNDLE) $(EXT_ENTITLEMENTS) $(APP_ENTITLEMENTS)
	# Sign extension first (it's embedded in the app)
	$(CODESIGN) --force --sign - --options runtime \
		--entitlements $(EXT_ENTITLEMENTS) \
		$(EXT_BUNDLE)
	# Sign the app (with embedded extension)
	$(CODESIGN) --force --sign - --options runtime \
		--entitlements $(APP_ENTITLEMENTS) \
		$(APP_BUNDLE)
	@echo ""
	@echo "=== Build complete: $(APP_BUNDLE) ==="
	@echo "Install with:  make install"

# ============================================================
# INSTALL
# ============================================================

install: $(APP_BUNDLE)
	@echo "Copying $(APP_NAME).app to /Applications/ ..."
	@rm -rf /Applications/$(APP_NAME).app
	@cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed /Applications/$(APP_NAME).app"
	# Also deploy extension to ~/Library/ExtensionKit/Extensions/ so
	# WallpaperAgent can discover it via ExtensionFoundation.
	@mkdir -p ~/Library/ExtensionKit/Extensions/
	@rm -rf ~/Library/ExtensionKit/Extensions/$(EXT_NAME).appex
	@cp -R $(EXT_BUNDLE) ~/Library/ExtensionKit/Extensions/
	@echo "Installed extension to ~/Library/ExtensionKit/Extensions/"

# ============================================================
# CLEAN
# ============================================================

$(BUILD):
	@mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)

.PHONY: all clean install
