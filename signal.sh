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

# Default location of the PID file. When empty, the default the value will be
# taken from the configuration.
MQ_PIDFILE=${MQ_PIDFILE:-}

# Signal to send
MQ_SIGNAL=${MQ_SIGNAL:-"-SIGHUP"}

# Process to look for
MQ_MOSQUITTO=${MQ_MOSQUITTO:-"mosquitto"}

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
  $cmdname looks for mosquitto through the PID file (preferred) or a running
  process, and sends it a signal (to reload).

Usage:
  $cmdname [-option arg]...

  where all dash-led single options are as follows:
    -v | --verbose  Be more verbose
    -p | --pidfile  Path to PID file

USAGE
  exit "$exitcode"
}

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
    -p | --pidfile)
      MQ_PIDFILE=$2; shift 2;;
    --pidfile=*)
      MQ_PIDFILE="${1#*=}"; shift 1;;

    -c | --config)
      MQ_CONFIG=$2; shift 2;;
    --config=*)
      MQ_CONFIG="${1#*=}"; shift 1;;

    -v | --verbose)
      MQ_VERBOSE=1; shift 1;;

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

if [ -z "$MQ_PIDFILE" ]; then
  MQ_PIDFILE=$(grep -E '^pid_file' "$MQ_CONFIG" | tail -n 1 | sed -E 's/^pid_file[[:space:]]+(.*)/\1/')
  if [ -n "$MQ_PIDFILE" ]; then
    log "Found PID file configuration as $MQ_PIDFILE"
  fi
fi

reload() {
  if [ -n "$1" ]; then
    log "Sending signal $MQ_SIGNAL to pid: $1"
    kill "$MQ_SIGNAL" "$1"
  fi
}

if [ -n "$MQ_PIDFILE" ] && [ -f "$MQ_PIDFILE" ]; then
  PID=$(cat "$MQ_PIDFILE")
  reload "$PID"
else
  mosquitto=$(command -v "$MQ_MOSQUITTO")
  processes=$(ps -o pid,args | tail -n +2 | awk '{print $1" "$2}')
  matching=$(printf %s\\n "$processes" | grep -cE "[[:digit:]]+ ($MQ_MOSQUITTO|$mosquitto)")
  if [ "$matching" = "0" ]; then
    warn "Cannot find a running $MQ_MOSQUITTO"
  elif [ "$matching" = "1" ]; then
    PID=$(printf %s\\n "$processes" | grep -E "[[:digit:]]+ ($MQ_MOSQUITTO|$mosquitto)" | awk '{print $1}')
    log "Found $MQ_MOSQUITTO as pid: $PID"
    reload "$PID"
  else
    warn "More than one $MQ_MOSQUITTO running!"
  fi
fi
