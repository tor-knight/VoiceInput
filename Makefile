APP_NAME    = VoiceInput
BUNDLE      = $(APP_NAME).app
BUILD_DIR   = .build/release
INSTALL_DIR = /Applications

.PHONY: build run install clean

build:
	@echo "Building $(APP_NAME)..."
	swift build -c release
	@echo "Assembling app bundle..."
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(BUNDLE)/Contents/
	cp Resources/*.icns $(BUNDLE)/Contents/Resources/ || true

	@echo "Done: $(BUNDLE)"

run: build
	open $(BUNDLE)

install: build
	@echo "Installing to $(INSTALL_DIR)/$(BUNDLE)..."
	rm -rf $(INSTALL_DIR)/$(BUNDLE)
	cp -r $(BUNDLE) $(INSTALL_DIR)/
	@echo "Installed."

clean:
	swift package clean
	rm -rf $(BUNDLE) .build
	@echo "Cleaned."
