.PHONY: help build build-universal app install clean test lint format

BIN_NAME := airpods-ctl
APP_NAME := AirPodsToggle
BUNDLE_ID := dev.borgo.airpods-ctl
BUILD_DIR := .build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
INSTALL_DIR := $(HOME)/Applications
SYMLINK_PATH := /opt/homebrew/bin/$(BIN_NAME)
HOST_ARCH := $(shell uname -m)
RELEASE_BIN_DIR_UNIVERSAL := $(BUILD_DIR)/apple/Products/Release
RELEASE_BIN_DIR_NATIVE := $(BUILD_DIR)/release

help:
	@echo "Targets:"
	@echo "  make build           — compile release binary for the host arch ($(HOST_ARCH))"
	@echo "  make build-universal — compile universal binary (arm64 + x86_64). Requires Xcode, not CLT-only."
	@echo "  make app             — assemble $(APP_NAME).app bundle (uses host build by default)"
	@echo "  make install         — install bundle to ~/Applications and symlink CLI"
	@echo "  make test            — run unit tests (requires Xcode for Testing.framework)"
	@echo "  make lint            — run swiftformat in lint mode"
	@echo "  make format          — apply swiftformat"
	@echo "  make clean           — remove build artifacts"

build:
	swift build -c release

build-universal:
	swift build -c release --arch arm64 --arch x86_64

app: build
	rm -rf $(APP_DIR)
	mkdir -p $(APP_DIR)/Contents/MacOS
	@if [ -f $(RELEASE_BIN_DIR_UNIVERSAL)/$(BIN_NAME) ]; then \
	  cp $(RELEASE_BIN_DIR_UNIVERSAL)/$(BIN_NAME) $(APP_DIR)/Contents/MacOS/$(BIN_NAME); \
	else \
	  cp $(RELEASE_BIN_DIR_NATIVE)/$(BIN_NAME) $(APP_DIR)/Contents/MacOS/$(BIN_NAME); \
	fi
	cp Resources/Info.plist $(APP_DIR)/Contents/Info.plist
	codesign --force --deep --sign - --options runtime --identifier $(BUNDLE_ID) $(APP_DIR)
	@echo "Built $(APP_DIR)"

install: app
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(APP_NAME).app
	cp -R $(APP_DIR) $(INSTALL_DIR)/
	ln -sf $(INSTALL_DIR)/$(APP_NAME).app/Contents/MacOS/$(BIN_NAME) $(SYMLINK_PATH)
	@echo "Installed $(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Symlinked $(SYMLINK_PATH)"

test:
	swift test \
	  -Xswiftc -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks \
	  -Xlinker -F/Library/Developer/CommandLineTools/Library/Developer/Frameworks
	@echo
	@echo "Note: if the test bundle fails to load Testing.framework on a CLT-only"
	@echo "install, you need a full Xcode for local testing. CI uses macOS runners"
	@echo "with Xcode pre-installed, so this only affects local dev."

lint:
	swiftformat Sources Tests --lint

format:
	swiftformat Sources Tests

clean:
	swift package clean
	rm -rf $(BUILD_DIR)/$(APP_NAME).app
