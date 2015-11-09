
define pack_ota_package
	$(hide) source $(PORT_TOOLS)/makefile_var_setup.sh $(DEVICE_NAME); \
        $(PORT_TOOLS)/pack_ota_package.sh $(DEVICE_NAME) "$(SUITABLE_DEVICES)"; \
		if [ $$? -ne 0 ];then \
			exit 1; \
		fi
endef

define build_ota_package
	$(hide) echo "build ota package"
endef

.PHONY: package build

##############################################################################################
# 生成OTA包
package:
	$(call pack_ota_package)

##############################################################################################
# build target for continuous integration
build:
	$(call build_ota_package)
