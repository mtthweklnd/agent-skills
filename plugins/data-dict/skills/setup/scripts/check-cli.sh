#!/usr/bin/env bash
#
# Find the data-dict CLI, check its version, and list its subcommands.
# Usage: check-cli.sh [--min VERSION]
#
# Prints `key: value` lines. Exit codes:
#   0  ok           1  missing
#   2  too old      3  found but not executable (chmod +x the printed path)

set -euo pipefail

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME

MIN_VERSION=0.0.3
VERBOSE=false

usage() {
    cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS]

Find the data-dict CLI, check it is at least the minimum version, and print
the subcommands this release provides.

OPTIONS:
    -m, --min VERSION   Minimum acceptable version (default: $MIN_VERSION)
    -v, --verbose       Show where each location was searched
    -h, --help          Show this help message

EXIT CODES:
    0 ok, 1 missing, 2 older than --min, 3 found but not executable
EOF
}

log() {
    if [[ $VERBOSE == true ]]; then
        printf '%s\n' "$*" >&2
    fi
}

die() {
    printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
    exit 1
}

# R's datadict::dd_install() unpacks the binary into R's user cache dir,
# which is never on PATH. Print the binary's path there, if any.
find_in_r_cache() {
    command -v Rscript >/dev/null 2>&1 || return 0
    local cache
    cache=$(Rscript -e 'cat(tools::R_user_dir("datadict", "cache"))' 2>/dev/null) || return 0
    log "searching R cache: $cache"
    [[ -d $cache ]] || return 0
    find "$cache" -maxdepth 3 -type f -name data-dict -print -quit
}

# Print the first data-dict binary found: PATH, then the install script's
# default (~/.cargo/bin, absent from PATH in non-login shells), then R's cache.
locate_cli() {
    local found
    if found=$(command -v data-dict 2>/dev/null); then
        printf '%s\n' "$found"
        return
    fi
    log "not on PATH"
    if [[ -f $HOME/.cargo/bin/data-dict ]]; then
        printf '%s\n' "$HOME/.cargo/bin/data-dict"
        return
    fi
    log "not in ~/.cargo/bin"
    find_in_r_cache
}

# Succeed when dotted version $1 >= $2. Pure Bash, so it runs on macOS's
# Bash 3.2, whose `sort` has no -V.
version_at_least() {
    local IFS=.
    local -a have want
    read -r -a have <<<"${1%%[-+]*}"
    read -r -a want <<<"$2"
    local i
    for i in 0 1 2; do
        if ((10#${have[i]:-0} > 10#${want[i]:-0})); then return 0; fi
        if ((10#${have[i]:-0} < 10#${want[i]:-0})); then return 1; fi
    done
}

main() {
    local cli version
    cli=$(locate_cli)

    if [[ -z $cli ]]; then
        printf 'status: missing\n'
        exit 1
    fi
    printf 'path: %s\n' "$cli"

    if [[ ! -x $cli ]]; then
        printf 'status: not-executable\n'
        exit 3
    fi

    if [[ $(command -v data-dict 2>/dev/null) != "$cli" ]]; then
        printf 'on_path: no\n'
    fi

    version=$("$cli" --version | awk '{print $2}')
    printf 'version: %s\nminimum: %s\n' "$version" "$MIN_VERSION"

    if ! version_at_least "$version" "$MIN_VERSION"; then
        printf 'status: too-old\n'
        exit 2
    fi

    printf 'status: ok\ncommands:\n'
    "$cli" --help | awk '/^Commands:/ {on=1; next} /^$/ {on=0} on'
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)    usage; exit 0 ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -m|--min)     [[ $# -ge 2 ]] || die "--min needs a version"
                      MIN_VERSION=$2; shift 2 ;;
        *)            die "unknown argument: $1" ;;
    esac
done

main
