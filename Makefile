export TARGET = macosx:clang:latest:10.11
export ARCHS = x86_64

export ADDITIONAL_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/common.mk

SIMBLTWEAK_NAME = TypeStatus

TypeStatus_FILES = $(wildcard *.x) $(wildcard *.m)
TypeStatus_FRAMEWORKS = Cocoa AppKit CoreGraphics
TypeStatus_PRIVATE_FRAMEWORKS = IMCore

include $(THEOS_MAKE_PATH)/simbltweak.mk

after-TypeStatus-all:: Resources/icon.icns

Resources/icon.icns: stuff/icon.iconset
	$(ECHO_COMPILING)iconutil --convert icns --output $@ $<$(ECHO_END)

before-install::
	$(ECHO_SIGNING)codesign --sign "Developer ID Application" $(THEOS_STAGING_DIR)/Library/Application\ Support/SIMBL/Plugins/TypeStatus.bundle$(ECHO_END)

after-install::
	$(ECHO_NOTHING)install.exec "killall Messages; sleep 0.1; open /Applications/Messages.app"$(ECHO_END)
