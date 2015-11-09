.PHONY: prepare
prepare:

# make prepare不能用于tos设备
ifeq ($(DEVICE_NAME),tos)
  $(error "[ERROR] target 'prepare' cannot used upon device $(DEVICE_NAME)")
endif
 
OTA_SYSTEM_PATH:=$(DEVICE_ROOT)/ota/system
# -----------------------------------------------------------------
# extract ota.zip file
OTA_EXTRACT_DIR:=$(DEVICE_ROOT)/ota
OTA_ZIP :=$(DEVICE_ROOT)/ota.zip
OTA_SYSTEM:=$(OTA_EXTRACT_DIR)/system
# 判断ota.zip是否存在
ifneq ($(OTA_ZIP), $(wildcard $(OTA_ZIP)))
  $(error "[ERROR] no ota.zip exist in '$(DEVICE_ROOT)/ota.zip'")
endif

$(OTA_EXTRACT_DIR): $(OTA_ZIP)
	$(hide) rm -rf $@ 
	$(hide) mkdir $@
	$(hide) unzip -o $< -d $@
	$(hide) if [ ! -d "$@/system" -o ! -f "$@/system/build.prop" ]; then \
		echo "[ERROR] ota.zip is not valid. cannot find 'system/build.prop' in ota.zip. please make sure you supply the correct ota.zip"; \
		rm -rf $@;\
		exit 1; \
	fi;\
	echo "unzip ota.zip finished"

#-----------------------------------------------------------------
# unpack boot.img file
BOOT_IMG := $(DEVICE_ROOT)/ota/boot.img
#判断boot.img是否存在
ifeq ($(BOOT_IMG), $(wildcard $(BOOT_IMG)))
UNPACK_BOOT_IMG:=$(PORT_TOOLS)/unpackbootimg.sh
ifeq ($(UNPACK_BOOTIMG_TOOL), $(wildcard $(UNPACK_BOOTIMG_TOOL)))
UNPACK_BOOT_IMG=$(UNPACK_BOOTIMG_TOOL);
endif
$(info $(UNPACK_BOOT_IMG))  
BOOT_IMAGE_UNPACK_DIR :=$(DEVICE_ROOT)/boot
$(BOOT_IMAGE_UNPACK_DIR):$(OTA_EXTRACT_DIR)
$(BOOT_IMAGE_UNPACK_DIR): $(BOOT_IMG)
	$(hide) rm -rf $@; 
	$(hide) mkdir -p $@
	@echo ">>>unpack boot.img...."
	$(hide) $(UNPACK_BOOT_IMG) $< $@; \
	if [ $$? -ne 0 ]; then \
		echo ">>>unpack boot.img failed."; \
		rm -rf $@;\
		exit 1; \
	fi
	
prepare:$(BOOT_IMAGE_UNPACK_DIR)
endif

# -----------------------------------------------------------------
# 反编译成smali
TAG:=$(IF_TAG_PREFIX)$(DEVICE_NAME)
COMPILED_SMALI_DIR:=$(DEVICE_ROOT)/smali

$(COMPILED_SMALI_DIR):$(OTA_EXTRACT_DIR)
	$(hide) rm -rf $@; 
	$(hide) mkdir -p $@
	@echo ">>>deodex begin...."
	$(hide) $(call env_set_up);\
	$(PORT_TOOLS)/apktool/deodex.sh $(DEVICE_ROOT)/ota/system $(DEVICE_NAME); \
	echo ">>>install framework-res.apk";\
	$(PORT_TOOLS)/install_framework.sh $(DEVICE_ROOT)/ota/system/framework $(IF_TAG_PREFIX)$(DEVICE_NAME); \
	if [ $$? -ne 0 ]; then \
		exit 1; \
	fi; \
	echo ">>>decompile framework jars & apks ..."; \
	RESOURCE_PACKAGE=$(CUSTOM_RESOURCE_PACKAGE) ;\
	if [ $$RESOURCE_PACKAGE=none ]; then \
		RESOURCE_PACKAGE=`find $(DEVICE_ROOT)/ota/system/framework/ -name "*.apk" ! -name "framework-res.apk" 2>/dev/null`;\
	fi ;\
	RESOURCE_PACKAGE=$(call get_framework_res_package $(OTA_SYSTEM/framework));\
	echo debug:$$RESOURCE_PACKAGE;\
	exit 0;\
	$(PORT_TOOLS)/decompile.sh $(OTA_SYSTEM_PATH) $@ $(TAG) $(DECOMPILE_PACKAGES) $$RESOURCE_PACKAGE; \
	if [ $$? -ne 0 ]; then \
		rm -rf $@;\
		exit 1; \
	fi; \
	if [ -n "$(EXTRA_DECOMPILE_PACKAGES)" ]; then \
		echo ">>>decompile extras apps ..."; \
		TOS_EXTRA_PACKAGES=; \
		for PACKAGE in $(EXTRA_DECOMPILE_PACKAGES); \
		do \
			if [ $${PACKAGE:0:4} = "TOS:" ]; then \
				TOS_EXTRA_PACKAGES="$$TOS_EXTRA_PACKAGES $${PACKAGE:4}"; \
			fi; \
		done; \
		if [ -n "$$TOS_EXTRA_PACKAGES" ]; then \
			$(PORT_TOOLS)/decompile.sh $(PORT_DEVICE)/tos/ota/system $(DEVICE_ROOT)/package/modified_apps/tos $(IF_TAG_PREFIX)tos $$TOS_EXTRA_PACKAGES; \
		fi; \
		TARGET_EXTRA_PACKAGES=; \
		for PACKAGE in $(EXTRA_DECOMPILE_PACKAGES); \
		do \
			if [ $${PACKAGE:0:7} = "TARGET:" ]; then \
				TARGET_EXTRA_PACKAGES="$$TARGET_EXTRA_PACKAGES $${PACKAGE:7}"; \
			fi; \
		done; \
		if [ -n "$$TARGET_EXTRA_PACKAGES" ]; then \
			$(PORT_TOOLS)/decompile.sh $(DEVICE_ROOT)/ota/system $(DEVICE_ROOT)/package/modified_apps/target $(IF_TAG_PREFIX)$(DEVICE_NAME) $$TARGET_EXTRA_PACKAGES; \
		fi; \
	fi;\
	echo ">>>decompile finished"

prepare:$(COMPILED_SMALI_DIR)
	@echo ">>>prepare finished"


 # -----------------------------------------------------------------
# 清理prepare产生的文件
 .PHONY: clean-prepare-yin
clean-prepare-yin:
	$(hide)rm -rf $(OTA_EXTRACT_DIR)
	$(hide)rm -rf $(COMPILED_SMALI_DIR)
	$(hide)rm -rf $(BOOT_IMAGE_UNPACK_DIR)