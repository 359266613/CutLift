include ../AxsCutLiftBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AxsCutLiftPrefs
AxsCutLiftPrefs_FILES = $(wildcard *.m)
AxsCutLiftPrefs_CFLAGS = -fobjc-arc -I../Sources
AxsCutLiftPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
AxsCutLiftPrefs_PRIVATE_FRAMEWORKS = Preferences
AxsCutLiftPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
