.PHONY: build test lint format strings check-strings screenshots app dmg install run release diagnose clean

CATALOG := Sources/WelpApp/Resources/Localizable.xcstrings
PRO_CATALOG := $(wildcard ee/Sources/WelpProEdition/Resources/Localizable.xcstrings)
STRINGS_BUILD := .build/strings
# Welp Pro (ee/) is built unless it is missing or WELP_FOSS_ONLY is set, like Package.swift.
PRO := $(if $(WELP_FOSS_ONLY),,$(wildcard ee/Sources))
# The app's executable: the official Welp Pro build, or the open-source core on its own.
EXECUTABLE := $(if $(PRO),WelpPro,Welp)

build:
	swift build

test:
	swift test

lint:
	swift format lint --strict --recursive Package.swift Plugins Sources Tests $(if $(PRO),ee/Sources ee/Tests)

format:
	swift format --in-place --recursive Package.swift Plugins Sources Tests $(if $(PRO),ee/Sources ee/Tests)

# Extracts every String(localized:) from the code into the String Catalogs, like Xcode does:
# adds new keys with their comments, marks removed ones stale. Translate in Xcode or in the
# JSON directly. Clean build on purpose, so every file is extracted. The core and Welp Pro
# (ee/) each have their own catalog; Pro's only gets the strings of its own source files.
strings:
	rm -rf $(STRINGS_BUILD)
	swift build --target WelpApp --scratch-path $(STRINGS_BUILD)/scratch \
		-Xswiftc -emit-localized-strings \
		-Xswiftc -emit-localized-strings-path -Xswiftc $(abspath $(STRINGS_BUILD))/data
	xcrun xcstringstool sync $(CATALOG) --stringsdata $(STRINGS_BUILD)/data/*.stringsdata
ifneq ($(PRO),)
	swift build --target WelpProEdition --scratch-path $(STRINGS_BUILD)/scratch \
		-Xswiftc -emit-localized-strings \
		-Xswiftc -emit-localized-strings-path -Xswiftc $(abspath $(STRINGS_BUILD))/pro
	xcrun xcstringstool sync $(PRO_CATALOG) --stringsdata \
		$(foreach f,$(wildcard ee/Sources/WelpProEdition/*.swift),$(STRINGS_BUILD)/pro/$(basename $(notdir $(f))).stringsdata)
endif

# Fails when a catalog is out of date with the code (run `make strings`).
check-strings: strings
	git diff --exit-code -- $(CATALOG) $(PRO_CATALOG)

# Renders the README screenshots (docs/images) in every app language.
screenshots:
	scripts/render-screenshots.sh

app:
	scripts/build-app.sh

# The release DMG's install window, unsigned, to check a new background or layout.
dmg: app
	scripts/build-dmg.sh build/Welp.app Welp build/Welp-preview.dmg
	open build/Welp-preview.dmg

install: app
	rm -rf /Applications/Welp.app
	cp -R build/Welp.app /Applications/Welp.app
	open /Applications/Welp.app

run: app
	open build/Welp.app

# Universal, Developer ID signed, notarized DMG: make release VERSION=1.0.0
release:
	scripts/release.sh $(VERSION)

diagnose: build
	.build/debug/$(EXECUTABLE) --diagnose

clean:
	rm -rf .build build
