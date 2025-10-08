TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = LLLLResUpiOS

LLLLResUpiOS_FILES = Tweak.xm
LLLLResUpiOS_CFLAGS = -fobjc-arc -std=c++17 -stdlib=libc++ -Wno-vla
LLLLResUpiOS_CXXFLAGS += -std=c++17 -stdlib=libc++ -Wno-vla

include $(THEOS_MAKE_PATH)/tweak.mk
