# CineClaw Apple TV (tvOS) Makefile
PROJECT_NAME = CineClawTV
SCHEME = CineClawTV
SDK = appletvos
CONFIGURATION ?= Debug
APPLE_TV_IP ?= 192.168.88.11

.PHONY: all generate build test clean deploy help

all: generate build

help:
	@echo "CineClaw tvOS Build Commands:"
	@echo "  make generate     - Generate CineClawTV.xcodeproj via xcodegen"
	@echo "  make build        - Compile tvOS app for Apple TV (arm64)"
	@echo "  make build-sim    - Compile tvOS app for tvOS Simulator"
	@echo "  make deploy       - Deploy and launch app on Apple TV ($(APPLE_TV_IP))"
	@echo "  make clean        - Remove build artifacts and derived data"

generate:
	@echo "==> Generating Xcode project..."
	xcodegen generate

build:
	@echo "==> Building CineClaw tvOS ($(CONFIGURATION))..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIGURATION) \
		-destination "generic/platform=tvOS" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build

build-sim:
	@echo "==> Building CineClaw tvOS for Simulator..."
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-sdk appletvsimulator \
		-configuration $(CONFIGURATION) \
		-destination "generic/platform=tvOS Simulator" \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO \
		CODE_SIGNING_ALLOWED=NO \
		build

clean:
	@echo "==> Cleaning..."
	rm -rf build DerivedData
	xcodebuild -project $(PROJECT_NAME).xcodeproj -scheme $(SCHEME) clean || true
