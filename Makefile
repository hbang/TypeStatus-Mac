TARGET = macosx:clang:10.8:10.7

include theos/makefiles/common.mk

BUNDLE_NAME = TypeStatus
TypeStatus_FILES = HBTypeStatusMac.m Tweak.xm
TypeStatus_INSTALL_PATH = $(HOME)/Library/Application Support/SIMBL/Plugins
TypeStatus_FRAMEWORKS = Cocoa AppKit CoreGraphics

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
	cp -r obj/TypeStatus.bundle release/TypeStatus.bundle
	cp ReleaseDS_Store release/.DS_Store
	cp background.png release/.background.png
