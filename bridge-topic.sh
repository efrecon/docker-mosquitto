#!/bin/sh

###
### Set topic mapping for Mosquitto Bridge configuration
### 
### This is done by copying the contents of the topics file
### and inserting them in the generated bridge.conf file

# Colourisation support for logging and output.
function _colour() {
  if [ "$MQ_INTERACTIVE" = "1" ]; then
    # shellcheck disable=SC2086
    printf '\033[1;31;'${1}'m%b\033[0m' "$2"
  else
    printf -- "%b" "$2"
  fi
}
function red() { _colour "40" "$1"; }
function blue() { _colour "34" "$1"; }

### 
### Accepted Arguments
###     $1 → Error Message
###
function handleError() {
    echo "[$(blue bridge-topic)] [$(red ERROR)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
    exit 1
}

### 
### Accepted Arguments
###     $1 → Last item in the topics file
###     $2 → The topics file
###
function setTopics() {
    ### Add remove everything between the '#topic' and the next config section
    sed -i -e '/^#topic/,/^# .*/{/^#topic/!{/^# .*/!d;};}' /mosquitto/config/sections/bridges.conf

    ### Insert the topics from the topics file
    sed -i '/^#topic/ r '"${2}" /mosquitto/config/sections/bridges.conf

    ### Append a space after the last topic inserted
    sed -i "\|^${1}|"'a \
        
        ' /mosquitto/config/sections/bridges.conf
}

if [ -z "${TOPICS_FILE}" ]; then
    handleError "Topic file env variable not set!"
fi

if [ ! -f "${TOPICS_FILE}" ]; then
    handleError "Topic file not found!"
fi

## Get the last topic from the topics file
LAST_TOPIC=$(tail -1 "${TOPICS_FILE}")

if [ -z "${LAST_TOPIC}" ]; then
    handleError "No topics found!"
fi

setTopics "${LAST_TOPIC}" "${TOPICS_FILE}"

exit 0