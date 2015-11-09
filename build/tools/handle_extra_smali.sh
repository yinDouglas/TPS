#!/bin/bash

if [ -z $PORT_DEVICE ]; then
    echo "you should export PORT_DEVICE env variable point to the PORT_ROOT/devices directory"
    exit 1
fi

DEVICE_NAME=$1
DEVICE_ROOT=$PORT_DEVICE/$DEVICE_NAME
PATCH_PATH=$DEVICE_ROOT/patch
TARGET_PATH=$PATCH_PATH/smali/target
CUSTOM_PATCH_DIR=$PORT_ROOT/custom_patch

# 创建工作目录
mkdir -p $TARGET_PATH


pattern_escape()
{
    local RESULT=${1//\[/\\\[}
    RESULT=${RESULT//\]/\\\]}
    RESULT=${RESULT//\$/\\\$}
    RESULT=${RESULT//\./\\\.}
    echo "$RESULT"
}

handle_override_smali()
{
    if [ -d "$CUSTOM_PATCH_DIR/override" ]; then
        local SEARCH_PATH=$CUSTOM_PATCH_DIR
        local SEARCH_LEVELS="override $DEVICE_BRAND $DEVICE_NAME $SW_VERSION"
        for LEVEL in `echo "$SEARCH_LEVELS"`
        do
            SEARCH_PATH=$SEARCH_PATH/$LEVEL
            if [ "$LEVEL" != "$SW_VERSION" ]; then
                SEARCH_PATH=$SEARCH_PATH/general
            fi
            
            if [ -d "$SEARCH_PATH" ]; then
                for FILE in `find "$SEARCH_PATH" -type f`
                do
                    local RELATIVE_PATH=${FILE:${#SEARCH_PATH}+1}
                    local EXT_NAME=${RELATIVE_PATH##*/*\.}
                    if [ "$EXT_NAME" = "smali" ]; then
                        # if no the last level(os band), the override files should be in general folder
                        local TARGET_FILE=`find "$TARGET_PATH" -path "*/$RELATIVE_PATH" 2>/dev/null`
                        if [ -z "$TARGET_FILE" ]; then
                            # target file not exist, create it
                            TARGET_FILE=$TARGET_PATH/$RELATIVE_PATH
                            mkdir -p `dirname "$TARGET_FILE"`
                        fi
                        cp -f "$FILE" "$TARGET_FILE"
                    elif [ "$EXT_NAME" = "method" ]; then
                        RELATIVE_PATH=${RELATIVE_PATH}
                        local FILE_NAME=`basename "$RELATIVE_PATH"`
                        FILE_NAME=${FILE_NAME%%\.*}
                        RELATIVE_PATH=`dirname "$RELATIVE_PATH"`/$FILE_NAME.smali
                        local TARGET_FILE=`find "$TARGET_PATH" -path "*/$RELATIVE_PATH" 2>/dev/null`
                        if [ -n "$TARGET_FILE" ]; then
                            replace_method_in_smali "$TARGET_FILE" "$FILE"
                        else
                            echo "[WARNING] cannot find corresponding target file for override method '$RELATIVE_PATH'"
                        fi
                    fi
                done
            fi

            SEARCH_PATH=`dirname "$SEARCH_PATH"`
        done
    fi
}

replace_method_in_smali()
{
    local SMALI_FILE=$1
    local METHOD_FILE=$2
    local EMPTY_LINE='\\'
    
    local METHOD_START=false
    local METHOD_DEFINE=
    local LINE_NUM=
    local OLD_IFS=$IFS
    local REPLACE_LINE=false
    local LINE_CNT=1
    # to keep white space of each line
    IFS=''
    while read LINE
    do  
        REPLACE_LINE=false
        if [ "${LINE:0:7}" = ".method" ]; then
            # method define
            if [ $METHOD_START = false ]; then
                METHOD_START=true
                METHOD_DEFINE=$LINE
                METHOD_DEFINE=`pattern_escape "$METHOD_DEFINE"`
                # delete the original method
                local METHOD_LINE=`grep -n "$METHOD_DEFINE" "$SMALI_FILE"`
                if [ -z "$METHOD_LINE" ]; then
                    echo "[WARNING] cannot find `head -n1 $METHOD_FILE` in $SMALI_FILE"
                    return 1
                fi
                
                LINE_NUM=`echo "$METHOD_LINE" | cut -d':' -f1`
                while true
                do
                    local LINE2=`sed -n "$LINE_NUM p" "$SMALI_FILE"`
                    # delete line
                    sed -i "$LINE_NUM d" "$SMALI_FILE"
                    if [ "${LINE2:0:11}" = ".end method" ]; then
                        break
                    fi
                done
                
                # check if the next line is also method definition line or not
                let local NEXT_LINE=$LINE_CNT+1
                local LINE3=`sed -n "$NEXT_LINE p" "$METHOD_FILE"`
                if [ "${LINE3:0:7}" != ".method" ]; then
                    REPLACE_LINE=true
                fi
            else
                # if there are 2 lines of method define
                # the 1st line is the original definition of this method
                # the 2nd line is the new definition that should be replaced
                REPLACE_LINE=true
            fi
        elif [ "${LINE:0:11}" = ".end method" ]; then
            # method end
            METHOD_START=false
            REPLACE_LINE=true
        else
            # normal line
            if [ $METHOD_START = true ]; then
                REPLACE_LINE=true
            fi
        fi
        
        if [ $REPLACE_LINE = true ]; then
            LINE=`pattern_escape "$LINE"`
            if [ -n "$LINE" ]; then
                # \\ means keeep white spaces
                sed -i "$LINE_NUM i\\$LINE" "$SMALI_FILE"
            else
                # add empty line
                sed -i "$LINE_NUM i$EMPTY_LINE" "$SMALI_FILE"
            fi
            ((LINE_NUM++))
        fi
        
        ((LINE_CNT++))
    done < "$METHOD_FILE"
    IFS=$OLD_IFS
}


handle_newly_added_files()
{
    local TOS_SMALI_PATH=$PORT_DEVICE/tos/smali
    for FILE in `find "$TOS_SMALI_PATH" -name "Tos*.smali"`
    do
        local RELATIVE_PATH=${FILE:${#TOS_SMALI_PATH}}
        # /framework2/smali/com/android/internal/os/TosPlugTestUsed.smali
        RELATIVE_PATH=${RELATIVE_PATH#/*/smali/}
        # com/android/internal/os/TosPlugTestUsed.smali
        RELATIVE_PATH=`dirname "$RELATIVE_PATH"`
        # com/android/internal/os
        local DEST_PATH=$TARGET_PATH/$RELATIVE_PATH
        mkdir -p "$DEST_PATH"
        cp -f "$FILE" "$DEST_PATH/"
    done
}

main()
{
    handle_newly_added_files
    handle_override_smali
}

main