#!/bin/ash

set -e

# Catch all MOSQUITTO_ prefix environment variable and match it in configure file
CONFIG=/mosquitto/config/mosquitto.conf
for VAR in $(env); do
    if [ -n "$(echo $VAR | grep -E '^MOSQUITTO_')" ]; then
        VAR_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO_([^=]*)=.*/\1/g" | tr '[:upper:]' '[:lower:]')
        VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/([^=]*)=.*/\1/g")
        # Config in mosquitto.conf
        if [ -n "$(cat $CONFIG |grep -E "^(^|^#*)$VAR_NAME")" ]; then
            echo "Configuring '$VAR_NAME' from env: $(eval echo \$$VAR_FULL_NAME)"
            sed -r -i "s/(^#*)($VAR_NAME)\s+(.*)/\2 $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $CONFIG
            sed -r -i "s/(^#*)($VAR_NAME)\s*$/$VAR_NAME $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $CONFIG
        fi
    fi
done


exec "$@"