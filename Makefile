TARGET = macosx:clang:10.8:latest

include theos/makefiles/common.mk

BUNDLE_NAME = TypeStatus
TypeStatus_FILES = Tweak.xm
TypeStatus_INSTALL_PATH = /Library/Parasite/Extensions
TypeStatus_FRAMEWORKS = AppKit Cocoa CoreGraphics
TypeStatus_PRIVATE_FRAMEWORKS = IMCore

include $(THEOS_MAKE_PATH)/bundle.mk

release: stage
	rm -rf release || true
	mkdir release
	cp stuff/How\ to\ Install\ EasySIMBL.webloc release
	rsync -rav obj/macosx/TypeStatus.bundle release/TypeStatus.bundle
	dropdmg --config-name=tsmac obj/macosx/TypeStatus.bundle
