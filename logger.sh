appname=$(basename "$0")

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
