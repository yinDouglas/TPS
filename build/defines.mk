
# refer to android build system, need build the MAKECMDGOALDS variable
SHOW_COMMANDS:= $(filter showcommands,$(MAKECMDGOALS))

ifeq ($(strip $(SHOW_COMMANDS)),)
hide := @
else
hide :=
endif

# apktool安装framework时的TAG前缀
IF_TAG_PREFIX := TPS_

define env_set_up
	source $(PORT_TOOLS)/makefile_var_setup.sh $(DEVICE_NAME); \
	source $(PORT_TOOLS)/java_setup.sh $(DEVICE_NAME)
endef

################
#deal dollar symbol
define dollar_symbol_makefile
$(shell echo $(1) |sed 's/\$$/\$$$$/g')
endef

#将dollar符号临时转换为下划线方便传值
define dollar_to_underline
$(subst $$,_,$(1))
endef

#将下划线重新转换为dollar
define underline_to_dollar
$(subst _,$$,$(1))
endef

#将下划线重新转换为dollar
define underline_to_dollar_two_transmit
$(subst _,$$$$$$$$,$(1))
endef

define underline_to_dollar_for_shell
$(subst _,$$$$$$$$,$(1))
endef
###################
#获取包名和类型形成的相对路径
#param_format:/TPS/devices/tos/smali/framework/smali/android/hardware/Camera.smali
#relative format: android/hardware/Camera.smali
define get_relative_path
$(shell echo $(subst $(1),,$(2)) |awk -F '/smali/' '{print $$2}')
endef

#根据相对路径查找目标机型对应smali文件
define find_cor_vendor_file
$(shell find "$1" -path */$(subst _,\$$,$(2)) | sed 's/\$$/\$$$$$$$$/g')
endef

#检测源tos文件是否需要patch
define check_to_patch
$(shell grep "^\.method.* tos_.*" $1)
endef

#获取文件夹下所有的smali文件
define get_all_smali_files_in_dir
$(strip $(filter-out $(1),$(shell if [ -d $(1) ]; then find $(1) -name *.smali | sed 's/\$$/\\\$$/g' | tee /tmp/find; fi)))
endef

#cp dir1 to dir2
define safe_dir_copy
$(shell if [ -d $(1) ]; then mkdir -p $(2) && cp -rf $(1)/* $(2); fi;)
endef

#获取文件中记录列表（如获取patch_failed.txt 中patch失败的文件）
define get_record_list_from_file
$(strip $(shell cat $(1)))
endef



