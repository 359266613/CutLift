DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include AxsCutLiftBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AxsCutLift
AxsCutLift_FILES = $(wildcard Hooks/*.xm Sources/*.m)
AxsCutLift_CFLAGS = -fobjc-arc -I./Headers -I./Sources
AxsCutLift_FRAMEWORKS = UIKit Foundation CoreFoundation Vision CoreImage CoreVideo
AxsCutLift_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += AxsCutLiftPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
