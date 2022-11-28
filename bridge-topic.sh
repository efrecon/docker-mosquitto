#!/bin/sh

###
### Set topic mapping for Mosquitto Bridge configuration
### 
### This is done by copying the contents of the topics file
### and inserting them in the generated bridge.conf file

### 
### Accepted Arguments
###     $1 → Error Message
###
function handleError() {
    echo "Topic Configuration Script: ${1}" 1>&2
    exit 1
}

### 
### Accepted Arguments
###     $1 → Last item in the topics file
###     $2 → The topics file
###
function setTopics() {
    ### Add remove everything between the '#topic' and the next config section
    sed -e '/^#topic/,/^# .*/{/^#topic/!{/^# .*/!d;};}' bridge.conf >bridge.new.conf

    ### Insert the topics from the topics file
    sed -i.tmp -e '/^#topic/ r '"${2}" bridge.new.conf

    ### Append a space after the last topic inserted
    sed -i.tmp -e "\|^${1}|"'a \
        
        ' bridge.new.conf
}


echo "${TOPIC_LIST_FILE}"
if [ -z "${TOPIC_LIST_FILE}" ]; then
    # echo "Topic file env variable not set!" 1>&2
    # exit 1
    handleError "Topic file env variable not set!"
fi

if [ ! -f "${TOPIC_LIST_FILE}" ]; then
    # echo "Topic file not found!" 1>&2
    # exit 1
    handleError "Topic file not found!"
fi

## Get the last topic from the topics file
LAST_TOPIC=$(tail -1 "${TOPIC_LIST_FILE}")
# @TODO: remove logging
echo "${LAST_TOPIC}"

if [ -z "${LAST_TOPIC}" ]; then
    # echo "No topics found!" 1>&2
    # exit 1
    handleError "No topics found!"
fi

setTopics LAST_TOPIC TOPIC_LIST_FILE

exit 0