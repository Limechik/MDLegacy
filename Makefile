export ARCHS = armv7
export TARGET = iphone:clang:6.1:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MDLegacy
MDLegacy_FILES = main.m MDAppDelegate.m MDUtil.m MDSettings.m MDHttp.m MDApi.m \
	MDModels.m MDLibrary.m MDImageLoader.m MDMangaCell.m MDCoverCell.m MDTheme.m MDDownloads.m MDNightMode.m MDTimePickerViewController.m \
	MDCatalogViewController.m MDLibraryViewController.m MDMangaViewController.m \
	MDReaderViewController.m MDSettingsViewController.m
# mbedTLS sources (see README): git clone into ./mbedtls
MDLegacy_FILES += $(wildcard mbedtls/library/*.c)
MDLegacy_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore ImageIO
MDLegacy_CFLAGS = -fobjc-arc -Imbedtls/include -Imbedtls/library -Wno-deprecated-declarations -Wno-everything -DMBEDTLS_DEBUG_C -DMBEDTLS_THREADING_C -DMBEDTLS_THREADING_PTHREAD -DMBEDTLS_PLATFORM_MS_TIME_ALT

include $(THEOS_MAKE_PATH)/application.mk
