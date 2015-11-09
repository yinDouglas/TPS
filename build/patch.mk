
VENDOR_SMALI_PATH=$(DEVICE_ROOT)/smali
TOS_SMALI_PATH=$(PORT_DEVICE)/tos/smali
PATCH_TARGET_PATH:=$(DEVICE_ROOT)/patch/smali/target

#构建合并单个文件的依赖
define merge_single_file
$(eval VENDOR_SMALI_FILE:=$(call find_cor_vendor_file,$(VENDOR_SMALI_PATH),$(1)))
$(eval RELATIVE_PATH_NORMAL:=$(call underline_to_dollar_two_transmit,$(1)))
$(eval TOS_SMALI__FILE:=$(call underline_to_dollar_for_shell,$(2)))
#构造patch依赖
$(PATCH_TARGET_PATH)/$(RELATIVE_PATH_NORMAL) : $(TOS_SMALI__FILE) $(VENDOR_SMALI_FILE)
	$(hide) $(PORT_TOOLS)/single_patch.sh $(subst $$,\$$$$,$(PATCH_TARGET_PATH)/$(RELATIVE_PATH_NORMAL) $(TOS_SMALI__FILE) $(VENDOR_SMALI_FILE))
endef

$(info >>>patch....)
ALL_TOS_SMALI_FILES:=$(sort $(call get_all_smali_files_in_dir, $(TOS_SMALI_PATH)))
#for test:
#ALL_TOS_SMALI_FILES:=/home/alexkzhang/github/TPS/devices/tos/smali/android.policy.jar/smali/com/android/internal/policy/impl/PhoneWindow\$$DecorView.smali

#查找需要进行patch的tos源文件集合
PATCH_TOS_FILE_COLLECTION:=
$(foreach tos_file,$(ALL_TOS_SMALI_FILES),\
	$(eval grep_results:=$(call check_to_patch,$(tos_file))) \
	$(if $(grep_results),$(eval PATCH_TOS_FILE_COLLECTION+= $(call dollar_symbol_makefile,$(tos_file))),))

#将dollar符号临时转换为下划线方便传值
PATCH_TOS_FILE_COLLECTION:=$(call dollar_to_underline,$(PATCH_TOS_FILE_COLLECTION))

#初始化目标patch集合
PATCH_TARGET_FILE_COLLECTION:=
$(foreach modified_tos_file,$(PATCH_TOS_FILE_COLLECTION), \
	$(eval RELATIVE_PATH := $(call get_relative_path,$(TOS_SMALI_PATH),$(modified_tos_file))) \
	$(eval PATCH_TARGET_FILE_COLLECTION+=$(PATCH_TARGET_PATH)/$(RELATIVE_PATH)) \
	$(eval $(call merge_single_file,$(RELATIVE_PATH),$(modified_tos_file))))

#将下划线还原成正常的dollar符号
PATCH_TARGET_FILE_COLLECTION:=$(call underline_to_dollar,$(PATCH_TARGET_FILE_COLLECTION))

.PHONY: patch clean-patch-yin
patch:$(PATCH_TARGET_FILE_COLLECTION) 
	@echo "-------------------"
	@echo ">>>copy tos newly added smali files and excute overide rules...."
	$(hide) $(PORT_TOOLS)/handle_extra_smali.sh $(DEVICE_NAME)
	@echo ">>>patch done"


#patch后，开发者理应只修改patch/smali/target文件夹中的文件，无需进行清理
#TODO：参考以前是如何做的,clean-patch需要换一个文件中写，因为，这里执行Makefile相关的代码
clean-patch-yin:
	@echo clean-patch done.
	
	
	
##############################################################################################
.PHONY: javapatch incpatch

TOS_OTA_NEW := $(PORT_DEVICE)/tos/ota_new
TOS_OTA_NEW_SMALI := $(PORT_DEVICE)/tos/smali_new

$(TOS_OTA_NEW):
	$(hide) if [ ! -f $(PORT_DEVICE)/tos/ota_new.zip ]; then \
			echo "[ERROR] $(PORT_DEVICE)/tos/ota_new.zip not found. you should put new version ota.zip of tos under '$(PORT_DEVICE)/tos'"; \
			exit 1; \
		fi; \
		unzip $(PORT_DEVICE)/tos/ota_new.zip -d $(PORT_DEVICE)/tos/ota_new; \
		if [ $$? -ne 0 ]; then \
			echo "[ERROR] unzip $(PORT_DEVICE)/tos/ota_new.zip failed"; \
			exit 1; \
		fi


$(TOS_OTA_NEW_SMALI): $(TOS_OTA_NEW)
	$(hide) source $(PORT_TOOLS)/makefile_var_setup.sh $(DEVICE_NAME); \
        $(PORT_TOOLS)/install_framework.sh $(PORT_DEVICE)/tos/ota_new/system/framework $(IF_TAG_PREFIX)tos_new; \
		if [ $$? -ne 0 ];then \
			exit 1; \
		fi; \
		SHELL_DECOMPILE_PACKAGES=$(DECOMPILE_PACKAGES); \
		if [ -z "$$SHELL_DECOMPILE_PACKAGES" ]; then \
			SHELL_DECOMPILE_PACKAGES=`grep -F "DECOMPILE_PACKAGES" $(PORT_DEVICE)/tos/Makefile | cut -d'=' -f2`; \
		fi; \
		SHELL_CUSTOM_RESOURCE_PACKAGE=$(CUSTOM_RESOURCE_PACKAGE); \
		if [ -z "$$SHELL_CUSTOM_RESOURCE_PACKAGE" ]; then \
			SHELL_CUSTOM_RESOURCE_PACKAGE=`grep -F "CUSTOM_RESOURCE_PACKAGE" $(PORT_DEVICE)/tos/Makefile | cut -d'=' -f2`; \
			if [ -z "$$SHELL_CUSTOM_RESOURCE_PACKAGE" ]; then \
				for FILE in `find $(PORT_DEVICE)/tos/ota_new/system/framework/ -name "*.apk" ! -name "framework-res.apk"`; \
				do \
					if [ -z "$$SHELL_CUSTOM_RESOURCE_PACKAGE" ]; then \
						SHELL_CUSTOM_RESOURCE_PACKAGE=`basename $$FILE`; \
					else \
						SHELL_CUSTOM_RESOURCE_PACKAGE="$$SHELL_CUSTOM_RESOURCE_PACKAGE `basename $$FILE`"; \
					fi;\
				done \
			fi; \
		fi; \
		$(PORT_TOOLS)/decompile.sh $(PORT_DEVICE)/tos/ota_new/system $(PORT_DEVICE)/tos/smali_new $(IF_TAG_PREFIX)tos_new $$SHELL_DECOMPILE_PACKAGES $$SHELL_CUSTOM_RESOURCE_PACKAGE; \
		if [ $$? -ne 0 ];then \
			exit 1; \
		fi

incpatch: $(TOS_OTA_NEW_SMALI) 
	$(hide) echo "$(CURDIR) is absolute path, $(PORT_ROOT) maybe a link path, so cannot compare directly" > /dev/null ; \
        source $(PORT_TOOLS)/makefile_var_setup.sh $(DEVICE_NAME); \
		if [ "`cat $(CURDIR)/Makefile | md5sum`" != "`cat $(PORT_ROOT)/Makefile | md5sum`" ];  then \
			$(PORT_TOOLS)/incremental_patch.sh $(DEVICE_NAME); \
		else \
			$(PORT_TOOLS)/incremental_patch.sh; \
		fi

##############################################################################################
incpackage:
	$(hide) if [ "`cat $(CURDIR)/Makefile | md5sum`" != "`cat $(PORT_ROOT)/Makefile | md5sum`" ];  then \
			$(PORT_TOOLS)/incremental_package.sh $(DEVICE_NAME); \
		else \
			$(PORT_TOOLS)/incremental_package.sh; \
		fi





