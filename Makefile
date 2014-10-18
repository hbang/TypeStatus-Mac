TARGET = macosx:clang:10.8:10.8
ARCHS = x86_64

include theos/makefiles/common.mk

BUNDLE_NAME = TypeStatus
TypeStatus_FILES = Tweak.xm
TypeStatus_INSTALL_PATH = $(HOME)/Library/Application Support/SIMBL/Plugins
TypeStatus_FRAMEWORKS = Cocoa AppKit CoreGraphics
TypeStatus_PRIVATE_FRAMEWORKS = IMCore
TypeStatus_LOGOSFLAGS = -c generator=internal

include $(THEOS_MAKE_PATH)/bundle.mk

after-stage::
	mkdir -p _/DEBIAN
	cp ./postinst _/DEBIAN/postinst
	chmod +x _/DEBIAN/postinst

after-install::
	open /Applications/Messages.app

release: stage
	rm -rf release || true
	mkdir release
	cp stuff/How\ to\ Install\ EasySIMBL.webloc release
	rsync -rav obj/macosx/TypeStatus.bundle release/TypeStatus.bundle
	dropdmg --config-name=tsmac obj/macosx/TypeStatus.bundle
