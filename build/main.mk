
# 使用bash作为makefile的shell环境
SHELL := /bin/bash

include $(PORT_BUILD)/defines.mk
include $(PORT_BUILD)/device.mk
include $(PORT_BUILD)/create.mk
include $(PORT_BUILD)/config.mk

ifeq ($(MAKECMDGOALS),prepare)
include $(PORT_BUILD)/prepare.mk
endif
#patch.mk会导致编译其他目标也变慢
ifeq ($(MAKECMDGOALS),patch)
include $(PORT_BUILD)/patch.mk
endif
ifeq ($(MAKECMDGOALS),repack)
include $(PORT_BUILD)/repack.mk
endif
include $(PORT_BUILD)/package.mk
include $(PORT_BUILD)/clean.mk