#!/bin/ash

set -e


if [ -t 1 ]; then
  MQ_INTERACTIVE=${MQ_INTERACTIVE:-1}
else
  MQ_INTERACTIVE=${MQ_INTERACTIVE:-0}
fi

# All (good?) defaults

# Set this to 1 for increase verbosity inside the entrypoint
MQ_VERBOSE=${MQ_VERBOSE:-0}

# Default location of the configuration. This matches the location used in the
# official image.
MQ_CONFIG=${MQ_CONFIG:-"/mosquitto/config/mosquitto.conf"}

# Sub-section detection matching rules. These come in pairs, first a glob-style
# matching pattern and then the name of the sub-section configuration that will
# be created. Pattern matching will not respect case and will occur against the
# content of the lines of the comment at the beginning of the section (without
# the comment character).
MQ_MATCHER=${MQ_MATCHER:-"default?listener* default extra?listener* extra *persist* persistence *log* logging *secur* security *bridge* bridges"}

# List of directives for files to watch for changes. Directives are composed of
# the name of a section (matching section names from above) and the name of a
# known mosquitto configuration variable in that section. When it is set, the
# path that it points at will be watched for changes and mosquitto will be told
# to reload its configuration using SIGHUP.
MQ_WATCHER=${MQ_WATCHER:-"security.acl_file security.password_file security.psk_file default.certfile default.keyfile extra.certfile extra.keyfile"}

# When watcher is not empty, and no PID file was specified in the main
# configuration file, this will be the location of the PID file that is passed
# further to mosquitto.
MQ_PIDFILE=${MQ_PIDFILE:-"/var/run/mosquitto.pid"}

# Dynamic vars
cmdname=$(basename "$(readlink -f "$0")")
dirname=$(dirname "$(readlink -f "$0")")
appname=${cmdname%.*}

# Print usage on stderr and exit
usage() {
  exitcode="$1"
  [ "$#" -gt "1" ] && error "$2"
  cat << USAGE >&2

Synopsis:
  $cmdname prepares the mosquitto configuration using the environment
  and pursues with running the command passed as an argument (usually
  mosquitto itself).

Usage:
  $cmdname [-option arg]...

  where all dash-led single options are as follows:
    -v | --verbose  Be more verbose
    -m | --matcher  Sub-section detection matching rules (in pairs)
    -c | --config   Path to main config file
    -w | --watcher  List directives pointing to files to watch for reload.

USAGE
  exit "$exitcode"
}

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
    -m | --matcher)
      MQ_MATCHER=$2; shift 2;;
    --matcher=*)
      MQ_MATCHER="${1#*=}"; shift 1;;

    -c | --config)
      MQ_CONFIG=$2; shift 2;;
    --config=*)
      MQ_CONFIG="${1#*=}"; shift 1;;

    -v | --verbose)
      MQ_VERBOSE=1; shift 1;;

    -w | --watcher)
      MQ_WATCHER=$2; shift 2;;
    --watcher=*)
      MQ_WATCHER="${1#*=}"; shift 1;;

    -\? | -h | --help)
      usage 0;;
    --)
      shift; break;;
    -*)
      echo "Unknown option: $1 !" >&2 ; usage 1;;
  esac
done

# Colourisation support for logging and output.
_colour() {
  if [ "$MQ_INTERACTIVE" = "1" ]; then
    # shellcheck disable=SC2086
    printf '\033[1;31;'${1}'m%b\033[0m' "$2"
  else
    printf -- "%b" "$2"
  fi
}
green() { _colour "32" "$1"; }
red() { _colour "40" "$1"; }
yellow() { _colour "33" "$1"; }
blue() { _colour "34" "$1"; }

# Conditional logging
log() {
  if [ "$MQ_VERBOSE" = "1" ]; then
    echo "[$(blue "$appname")] [$(green info)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
  fi
}

warn() {
  echo "[$(blue "$appname")] [$(yellow WARN)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
}

error() {
  echo "[$(blue "$appname")] [$(red ERROR)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
}


# First pass: Catch all MOSQUITTO_ prefixed environment variables and match them
# in configure file, do not take care of sections variables, i.e. variables
# starting with MOSQUITTO__ (note the double underscore)
log "Environment resolution in main configuration at $MQ_CONFIG"
for VAR in $(env); do
  if [ -n "$(echo "$VAR" | grep -E '^MOSQUITTO_' | grep -Ev '^MOSQUITTO__')" ]; then
    VAR_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO_([^=]*)=.*/\1/g" | tr '[:upper:]' '[:lower:]')
    VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/([^=]*)=.*/\1/g")
    # Config in mosquitto.conf
    if grep -Eq "^(^|^#*)$VAR_NAME" "$MQ_CONFIG"; then
      log "Configuring '$VAR_NAME' from env: $(eval echo \$$VAR_FULL_NAME)"
      sed -r -i "s/(^#*)($VAR_NAME)\s+(.*)/\2 $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" "$MQ_CONFIG"
      sed -r -i "s/(^#*)($VAR_NAME)\s*$/$VAR_NAME $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" "$MQ_CONFIG"
    fi
  fi
done

# Use the slicer to detect where the include directory is pointed at.
INCL=$("${dirname%/}/slicer.tcl" -dryrun true -- "$MQ_CONFIG" | head -n1)

# Slice the file into sections files in the include directory if one was
# specified.
if [ -n "$INCL" ]; then
  log "Slicing $MQ_CONFIG to sections at $INCL"
  "${dirname%/}/slicer.tcl" -sections "$MQ_MATCHER" -- "$MQ_CONFIG"
  # Second pass: Catch all MOSQUITTO__ prefixed environment variables and
  # match them in the sections files.
  for VAR in $(env); do
    if [ -n "$(echo "$VAR" | grep -E '^MOSQUITTO__')" ]; then
      VAR_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO__[^_]+__([^=]*)=.*/\1/g" | tr '[:upper:]' '[:lower:]')
      SECTION_NAME=$(echo "$VAR" | sed -r "s/MOSQUITTO__([^_]+)__[^=]*=.*/\1/g" | tr '[:upper:]' '[:lower:]')
      VAR_FULL_NAME=$(echo "$VAR" | sed -r "s/([^=]*)=.*/\1/g")
      # Config in mosquitto.conf
      SECTION_CONFIG=${INCL%/}/${SECTION_NAME}.conf
      log "Environment resolution in section configuration at $SECTION_CONFIG"
      if [ -f "$SECTION_CONFIG" ]; then
        if [ -n "$(cat $SECTION_CONFIG |grep -E "^(^|^#*)$VAR_NAME")" ]; then
          log "Configuring '$VAR_NAME' from env: $(eval echo \$$VAR_FULL_NAME)"
          sed -r -i "s/(^#*)($VAR_NAME)\s+(.*)/\2 $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $SECTION_CONFIG
          sed -r -i "s/(^#*)($VAR_NAME)\s*$/$VAR_NAME $(eval echo \$$VAR_FULL_NAME|sed -e 's/\//\\\//g')/g" $SECTION_CONFIG
        fi
      fi
    fi
  done

  # Check if a topic configuration file is declared
  if [ ! -z "${TOPICS_FILE}" ]; then
    # Only allow bulk topic setting when there is no explicit bridge topic set
    if [ -z "${MOSQUITTO__BRIDGES__TOPIC}" ]; then
      ("${dirname%/}/bridge-topic.sh" "${TOPICS_FILE}")
    else
      log "Bridge Topic already set! Skipping topic list configuration"
    fi
  fi

  # If slicing was performed, pursue watching relevant files for changes
  if [ -n "$MQ_WATCHER" ]; then
    # Look for a PID file, or force one. Note that even if we force a PID file,
    # it might not be created by mosquitto as the PID file is only created when
    # it is running in daemon mode.
    if grep -qE '^pid_file' "$MQ_CONFIG"; then
      pidfile=$(grep -E '^pid_file' "$MQ_CONFIG" | tail -n 1 | sed -E 's/^pid_file[[:space:]]+(.*)/\1/')
      log "PID file at $pidfile"
    else
      log "Forcing PID file at $MQ_PIDFILE"
      sed -E -i "s;^#*pid_file.*;pid_file ${MQ_PIDFILE};g" "$MQ_CONFIG"
      pidfile=$MQ_PIDFILE
    fi

    # Look for possible parameters in sections, and, for each that is set, ask
    # mosquitto to reload its configuration.
    for directive in $MQ_WATCHER; do
      section=$(printf %s\\n "$directive" | cut -d "." -f 1)
      var=$(printf %s\\n "$directive" | cut -d "." -f 2)
      if [ -f "${INCL}/${section}.conf" ]; then
        if grep -qE "^${var}[[:space:]]+" "${INCL}/${section}.conf"; then
          fpath=$(grep -E "^${var}[[:space:]]+" "${INCL}/${section}.conf" | tail -n 1 | sed -E "s/^${var}[[:space:]]+(.*)/\1/")
          # Watch the file pointed at by the parameter $var (path is now at
          # $fpath). Whenever it changes execute signal.sh. signal.sh will
          # either read the content of the PID file, or look for a mosquitto
          # process, and send it the SIGHUP signal so that it reloads its
          # configuration.
          log "Watching $fpath for changes, from directive $directive"
          if [ "$MQ_VERBOSE" = "1" ]; then
            "${dirname%/}/watch.sh" --path "$fpath" --command "${dirname%/}/signal.sh --verbose --config \"$MQ_CONFIG\"" &
          else
            "${dirname%/}/watch.sh" --path "$fpath" --command "${dirname%/}/signal.sh --config \"$MQ_CONFIG\"" &
          fi
        fi
      else
        warn "Section $section does not exist under $INCL"
      fi
    done
  fi
fi

log "Running: $@"
exec "$@"