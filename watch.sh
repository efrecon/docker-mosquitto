#!/usr/bin/env sh


if [ -t 1 ]; then
  WATCH_INTERACTIVE=${WATCH_INTERACTIVE:-1}
else
  WATCH_INTERACTIVE=${WATCH_INTERACTIVE:-0}
fi

# All (good?) defaults
WATCH_VERBOSE=${WATCH_VERBOSE:-0}
WATCH_PERIOD=${WATCH_PERIOD:-5}
WATCH_PATH=${WATCH_PATH:-""}
WATCH_COMMAND=${WATCH_COMMAND:-}
WATCH_WITHARG=${WATCH_WITHARG:-0}
WATCH_CONTENT=${WATCH_CONTENT:-1}

# Dynamic vars
cmdname=$(basename "$(readlink -f "$0")")
appname=${cmdname%.*}

# Print usage on stderr and exit
usage() {
  exitcode="$1"
  [ "$#" -gt "1" ] && error "$2"
  cat << USAGE >&2

Synopsis:
  $cmdname watches a file for changes and execute a command when it does.

Usage:
  $cmdname [-option arg]...

  where all dash-led single options are as follows:
    -v              Be more verbose
    -f path         Path to file to watch (mandatory)
    -c command      Command to execute on changes
    -p period       Period at which to watch for changes (in seconds).
    --content       Check content has changed also.
    --with-arg      Pass path to file as last argument to command.

Description:
  $cmdname also works with non-existing files:
  * Whenever the file starts to exist, $cmdname will react and execute
    the command.
  * Whenever the file ceases to exist, $cmdname will react and execute
    the command (but this might be incompatible with --with-arg)

USAGE
  exit "$exitcode"
}

# Parse options
while [ $# -gt 0 ]; do
  case "$1" in
    -f | --file | --path)
      WATCH_PATH=$2; shift 2;;
    --file=* | --path=*)
      WATCH_PATH="${1#*=}"; shift 1;;

    -p | --period)
      WATCH_PERIOD=$2; shift 2;;
    --period=*)
      WATCH_PERIOD="${1#*=}"; shift 1;;

    -v | --verbose)
      WATCH_VERBOSE=1; shift 1;;

    -c | --command)
      WATCH_COMMAND=$2; shift 2;;
    --command=*)
      WATCH_COMMAND="${1#*=}"; shift 1;;

    --with-arg)
      WATCH_WITHARG=1; shift 1;;

    --content)
      WATCH_CONTENT=1; shift 1;;

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
  if [ "$WATCH_INTERACTIVE" = "1" ]; then
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
  if [ "$WATCH_VERBOSE" = "1" ]; then
    echo "[$(blue "$appname")] [$(green info)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
  fi
}

warn() {
  echo "[$(blue "$appname")] [$(yellow WARN)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
}

error() {
  echo "[$(blue "$appname")] [$(red ERROR)] [$(date +'%Y%m%d-%H%M%S')] $1" >&2
}

if [ -z "$WATCH_PATH" ]; then
  usage 1 "You must specify the path to a file!"
fi

filesum() {
  if [ -f "$WATCH_PATH" ]; then
    md5sum "$WATCH_PATH"
  else
    printf %s\\n "XX"
  fi
}

filestat() {
  if [ -f "$WATCH_PATH" ]; then
    stat -c %Z "$WATCH_PATH"
  else
    printf %d\\n "-1"
  fi
}

LTIME=$(filestat)
LSUM=
if [ "$WATCH_CONTENT" = "1" ]; then
  log "Watching content of $WATCH_PATH and calling $WATCH_COMMAND on changes"
  LSUM=$(filesum)
else
  log "Watching activity on $WATCH_PATH and calling $WATCH_COMMAND on changes"
fi
while true; do
  sleep "$WATCH_PERIOD"
  ATIME=$(filestat)
  if [ "$ATIME" != "$LTIME" ]; then
    [ "$WATCH_CONTENT" = "1" ] && ASUM=$(filesum)
    if [ "$WATCH_CONTENT" = "0" ] || [ "$ASUM" != "$LSUM" ]; then
      if [ -z "$WATCH_COMMAND" ]; then
        log "$WATCH_PATH has changed, but no command specified"
      else
        if [ "$WATCH_WITHARG" = "1" ]; then
          log "$WATCH_PATH has changed, running $WATCH_COMMAND with file path as argument"
          eval "$WATCH_COMMAND" "$WATCH_PATH"
        else
          log "$WATCH_PATH has changed, running $WATCH_COMMAND"
          eval "$WATCH_COMMAND"
        fi
      fi
    fi
    if [ "$WATCH_CONTENT" = "1" ] && [ "$ASUM" = "$LSUM" ]; then
      log "File was modified, but content identical"
    fi
    LTIME=$ATIME
    LSUM=$ASUM
  fi
done