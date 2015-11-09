
TOS_SMALI_PATH=$(PORT_DEVICE)/tos/smali
VENDOR_SMALI_PATH=$(DEVICE_ROOT)/smali
PATCH_TARGET_PATH:=$(DEVICE_ROOT)/patch/smali/target
PACK_SMALI_PATH:=$(DEVICE_ROOT)/patch/smali/pack
PATCH_FAILED_RECORD_FILE:=$(PATCH_TARGET_PATH)/patch_failed.txt


###################
#根据patch_failed.txt判断是否所有冲突已解决
ifeq ($(PATCH_FAILED_RECORD_FILE), $(wildcard $(PATCH_FAILED_RECORD_FILE)))
  $(info -----------------------------------)
  $(info >>>check if all patch conflicts have been resolved....)
  #获取patch失败的文件列表
  PATCH_FAILED_SMALI_FILES:=$(call get_record_list_from_file,$(PATCH_FAILED_RECORD_FILE))
  $(info $(PATCH_FAILED_SMALI_FILES))
  #检测是否所有的patch冲突文件，已经解决完毕
  $(foreach patch_target_file,$(PATCH_FAILED_SMALI_FILES),\
	$(if $(wildcard $(PATCH_TARGET_PATH)/$(patch_target_file)),, \
		$(error '$(patch_target_file)' not exist. you can mannually solve 'make patch' conflicts or execute 'make javapatch')))
endif


###################
#拷贝反编译的jar或apk smali文件到pack目录
$(info -----------------------------------)
$(info >>>copy decompiled packages to pack path....)
$(foreach package,$(DECOMPILE_PACKAGES),\
	 $(if $(wildcard $(PACK_SMALI_PATH)/$(package)),, \
		$(eval $(call safe_dir_copy,$(VENDOR_SMALI_PATH)/$(package),$(PACK_SMALI_PATH)/$(package))) \
	) \
)

###################
.PHONY: repack clean-repack-yin

#将原厂smali文件和patch后的smali文件进行合并
repack:
	@echo "-----------------------------------"
	@echo ">>>prepared the patched packages smali files"
	$(hide) $(PORT_TOOLS)/repack_smali_files.sh $(PATCH_TARGET_PATH) $(PACK_SMALI_PATH) $(VENDOR_SMALI_PATH) $(TOS_SMALI_PATH)
	@echo  ">>>repack done "

clean-repack-yin:
	$(hide) rm -rf $(PACK_SMALI_PATH)/*
	@echo ">>>clean repack done "

