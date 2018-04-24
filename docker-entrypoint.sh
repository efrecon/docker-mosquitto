#!/bin/ash

set -e

# Default location of the configuration. This matches the location used in the
# official image. We might want to provide options to specify this from the
# outside.
CONFIG=/mosquitto/config/mosquitto.conf
# Sub-section detection matching rules. These come in pairs, first a glob-style
# matching pattern and then the name of the sub-section configuration that will
# be created. Pattern matching will not respect case and will occur against the
# content of the lines of the comment at the beginning of the section (without
# the comment character).
MATCHER="default?listener* default extra?listener* listener *persist* persistence *log* logging *secur* security *bridge* bridges"

# First pass: Catch all MOSQUITTO_ prefixed environment variables and match them
# in configure file, do not take care of sections variables, i.e. variables
# starting with MOSQUITTO__ (note the double underscore)
echo "Environment resolution in main configuration at $CONFIG"
for VAR in $(env); do
    if [ -n "$(echo $VAR | grep -E '^MOSQUITTO_' | grep -Ev '^MOSQUITTO__')" ]; then
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

# Use the slicer to detect where the include directory is pointed at.
INCL=$(/slicer.tcl -dryrun true -- $CONFIG | head -n1)

# Slice the file into sections files in the include directory if one was
# specified.
if [ -n "$INCL" ]; then
    /slicer.tcl -sections "$MATCHER" -- $CONFIG
    # Second pass: Catch all MOSQUITTO__ prefixed environment variables and
    # match them in the sections files.
    for VAR in $(env); do
        if [ -n "$(echo $VAR | grep -E '^MOSQUITTO__')" ]; then
            VAR_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO__[^_]+__([^=]*)=.*/\1/g" | tr '[:upper:]' '[:lower:]')
            SECTION_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO__([^_]+)__[^=]*=.*/\1/g" | tr '[:upper:]' '[:lower:]')
            VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/([^=]*)=.*/\1/g")
            # Config in mosquitto.conf
            SECTION_CONFIG=${INCL}/${SECTION_NAME}.conf
            echo "Environment resolution in section configuration at $SECTION_CONFIG"
            if [ -f "$SECTION_CONFIG" ]; then
                if [ -n "$(cat $SECTION_CONFIG |grep -E "^(^|^#*)$VAR_NAME")" ]; then
                    echo "Configuring '$VAR_NAME' from env: $(eval echo \$$VAR_FULL_NAME)"
                    sed -r -i "s/(^#*)($VAR_NAME)\s+(.*)/\2 $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $SECTION_CONFIG
                    sed -r -i "s/(^#*)($VAR_NAME)\s*$/$VAR_NAME $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $SECTION_CONFIG
                fi
            fi
        fi
    done
fi



exec "$@"