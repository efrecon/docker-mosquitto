#!/bin/sh

###
### Set topic mapping for Mosquitto Bridge configuration
###
### This is done by copying the contents of the topics file
### and inserting them in the generated bridge.conf file
### Accepted Arguments
###     $1 → The topic list file
###     $2 → The configuration file to update

source ./logger.sh

###
### Accepted Arguments
###     $1 → Error Message
###
function handleError() {
    error "${1}"
    exit 1
}

###
### Accepted Arguments
###     $1 → Last item in the topics file
###     $2 → The topics file
###     $3 → The target configuration file
###
function setTopics() {
    ### Add remove everything between the '#topic' and the next config section
    sed -i -e '/^#topic/,/^# .*/{/^#topic/!{/^# .*/!d;};}' "${3}"

    ### Insert the topics from the topics file
    sed -i '/^#topic/ r '"${2}" "${3}"

    ### Append a space after the last topic inserted
    sed -i "\|^${1}|"'a \
        
        ' "${3}"
}

### Map arguments to meaningful variables
TOPICS_FILE="$1"
BRIDGE_CONF_FILE="$2"

if [ -z "${TOPICS_FILE}" ]; then
    handleError "Topic file env variable not set!"
fi

if [ -z "${BRIDGE_CONF_FILE}" ]; then
    handleError "Configuration file env variable not set!"
fi

if [ ! -f "${BRIDGE_CONF_FILE}" ]; then
    handleError "Target configuration file not found!"
fi

if [ ! -f "${TOPICS_FILE}" ]; then
    handleError "Topic file not found!"
fi

## Get the last topic from the topics file
LAST_TOPIC=$(tail -1 "${TOPICS_FILE}")

if [ -z "${LAST_TOPIC}" ]; then
    handleError "No topics found!"
fi

setTopics "${LAST_TOPIC}" "${TOPICS_FILE}" "${BRIDGE_CONF_FILE}"

exit 0
