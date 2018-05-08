export TARGET = macosx:clang:latest:10.11
export ARCHS = x86_64

export ADDITIONAL_CFLAGS = -fobjc-arc -include Global.h

include $(THEOS)/makefiles/common.mk

SIMBLTWEAK_NAME = TypeStatus

TypeStatus_FILES = $(wildcard *.x)
TypeStatus_FRAMEWORKS = Cocoa AppKit CoreGraphics
TypeStatus_PRIVATE_FRAMEWORKS = IMCore

include $(THEOS_MAKE_PATH)/simbltweak.mk

after-TypeStatus-all:: Resources/AppIcon.icns

Resources/AppIcon.icns: stuff/AppIcon.iconset
	$(ECHO_COMPILING)iconutil --convert icns --output $@ $<$(ECHO_END)

after-install::
	$(ECHO_NOTHING)install.exec "killall Messages; sleep 0.1; open /Applications/Messages.app"$(ECHO_END)
