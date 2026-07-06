.PHONY: gen build test probe clean

gen:
	xcodegen generate

build: gen
	xcodebuild -project Kotori.xcodeproj -scheme Kotori \
		-destination 'generic/platform=iOS Simulator' \
		CODE_SIGNING_ALLOWED=NO build

test:
	cd KotoriKit && swift test

probe:
	cd KotoriKit && swift run kotori-probe user jack

clean:
	rm -rf Kotori.xcodeproj KotoriKit/.build
