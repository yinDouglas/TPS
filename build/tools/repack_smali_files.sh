#!/bin/bash

###################
# 将smali文件重新repack

if [ $# -ne 4 ]; then
    echo "usage: PATCH_TARGET_PATH PACK_SMALI_PATH VENDOR_SMALI_PATH TOS_SMALI_PATH"
    exit 1
fi

PATCH_TARGET_PATH=$1
PACK_SMALI_PATH=$2
VENDOR_SMALI_PATH=$3
TOS_SMALI_PATH=$4

# 拷贝需要覆盖的smali文件到pack目录
for SMALI_FILE in `find "$PATCH_TARGET_PATH" -name "*.smali"`
do
	RELATIVE_PATH=${SMALI_FILE:${#PATCH_TARGET_PATH}+1}
	ORIGINAL_FILE=`find "$VENDOR_SMALI_PATH" -path "*/$RELATIVE_PATH" | head -n1`
	if [ -f "$ORIGINAL_FILE" ]; then
		RELATIVE_PATH=${ORIGINAL_FILE:${#VENDOR_SMALI_PATH}+1}
		cp -f "$SMALI_FILE" "$PACK_SMALI_PATH/$RELATIVE_PATH"
	else
		# 新加的文件，在tos目录中查找
		ORIGINAL_FILE=`find "$TOS_SMALI_PATH" -path "*/$RELATIVE_PATH" | head -n1`
		if [ -f "$ORIGINAL_FILE" ]; then
			RELATIVE_PATH=${ORIGINAL_FILE:${#TOS_SMALI_PATH}+1}
			mkdir -p `dirname "$PACK_SMALI_PATH/$RELATIVE_PATH"`
			cp -f "$SMALI_FILE" "$PACK_SMALI_PATH/$RELATIVE_PATH"
		else
			# TODO 是不是可以直接放到android.policy下面？
			echo "[ERROR] cannot find destination folder for $SMALI_FILE"
			exit 1
		fi
	fi
done

#将framework-qrom.jar中所有的smali文件拷贝到android.policy.jar中
cp -rf "$TOS_SMALI_PATH/framework-qrom.jar/smali" "$PACK_SMALI_PATH/android.policy.jar/"



