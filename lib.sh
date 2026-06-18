#!/usr/bin/env bash
# tm/lib.sh — Shared colors, output helpers, and the transmission-remote wrapper.
# Sourced by all other modules. Do not execute directly.

AMBER='\033[0;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ── Connection settings ───────────────────────────────────────────────────────
# TR_AUTH   : "user:password" — read from the environment (see README / cheatsheet).
#             If unset, prompt_auth() asks for it once at launch (session only).
# TR_HOST   : optional "host:port" (e.g. "127.0.0.1:9091" or "silky-percentage:9091").
#             Leave empty to talk to the local daemon on the default port.
# DOWNLOAD_DIR : default download directory, used by the "Retrieve finished files"
#                screen. Matches the path from your settings.json.
TR_HOST="${TR_HOST:-}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/var/lib/transmission-daemon/downloads}"
SETTINGS_JSON="${SETTINGS_JSON:-/etc/transmission-daemon/settings.json}"

# ── Output helpers ────────────────────────────────────────────────────────────

divider()         { echo -e "${CYAN}────────────────────────────────────────────────────${RESET}"; }
header()          { clear; echo -e "\n${BOLD}${CYAN}$1${RESET}"; divider; }
desc()            { echo -e "${AMBER}▸ $1${RESET}"; }
run()             { echo -e "${GREEN}\$ $1${RESET}"; eval "$1"; echo; }
analysis_header() { echo -e "\n${BOLD}${CYAN}── Notes ───────────────────────────────────────────${RESET}"; }

pause() {
    echo -e "\n${DIM}Press Enter to return to menu...${RESET}"
    # Drain input buffered while the action ran (residual escape sequences,
    # the Enter used to quit less, etc.) before blocking for a fresh keypress.
    while read -r -t 0.05 _flush 2>/dev/null; do :; done
    read -r
}

# ── Status markers (interpret command output, same vocabulary as sec-audit) ───

flag() { echo -e "  ${RED}${BOLD}[!]${RESET} $1"; }
warn() { echo -e "  ${AMBER}${BOLD}[~]${RESET} $1"; }
ok()   { echo -e "  ${GREEN}${BOLD}[✓]${RESET} $1"; }
info() { echo -e "  ${CYAN}[-]${RESET} $1"; }
tip()  { echo -e "    ${DIM}↳ $1${RESET}"; }

# ── transmission-remote wrapper ───────────────────────────────────────────────
# _tr ARGS...   Runs transmission-remote with auth (and host, if set) injected.
#               Returns the command's own exit status.
_tr() {
    if [ -n "$TR_HOST" ]; then
        transmission-remote "$TR_HOST" --auth "$TR_AUTH" "$@"
    else
        transmission-remote --auth "$TR_AUTH" "$@"
    fi
}

# run_tr ARGS...  Prints a REDACTED command line (password shown as ***), then
#                 runs it and pages the output. We never echo $TR_AUTH to the
#                 screen — the cheatsheet's whole point is that the password is
#                 sensitive, so it should not end up in your scrollback either.
run_tr() {
    local host_part=""
    [ -n "$TR_HOST" ] && host_part="$TR_HOST "
    echo -e "${GREEN}\$ transmission-remote ${host_part}--auth *** $*${RESET}"
    local out; out=$(_tr "$@" 2>&1)
    pager "$out"
    echo
}

# run_sys CMD   Prints and runs a plain system command (wg, ss, systemctl, ...),
#               paging long output. Use for everything that is NOT transmission.
run_sys() {
    echo -e "${GREEN}\$ $1${RESET}"
    local out; out=$(eval "$1" 2>&1)
    pager "$out"
    echo
}

# ── Auth bootstrap ────────────────────────────────────────────────────────────
# If TR_AUTH is not exported, ask for it once. Stored only for this session;
# the user is told how to make it persist. Password input is hidden.
prompt_auth() {
    [ -n "$TR_AUTH" ] && return 0
    clear
    echo -e "${BOLD}${CYAN}Transmission authentication${RESET}"
    divider
    echo -e "${AMBER}TR_AUTH is not set in your environment.${RESET}"
    echo -e "Enter the daemon's RPC credentials for this session.\n"
    local u p
    read -r -p "  Username: " u
    read -r -s -p "  Password: " p; echo
    export TR_AUTH="${u}:${p}"
    echo
    echo -e "${DIM}Tip: to skip this next time, add to ~/.bashrc:${RESET}"
    echo -e "${DIM}  echo 'export TR_AUTH=\"${u}:<password>\"' >> ~/.bashrc${RESET}"
    echo -e "${DIM}(plaintext-readable by anyone with shell access to your user)${RESET}"
    sleep 1
}

# ── Input helpers ─────────────────────────────────────────────────────────────
# ask VAR "Prompt"      Reads a line into the named variable (visible input).
ask() {
    local __var="$1" __prompt="$2" __reply
    read -r -p "  ${__prompt}: " __reply
    printf -v "$__var" '%s' "$__reply"
}

# ask_id VAR            Reads a torrent ID, validating it is a number (or 'all'
#                       when $2 = "allow_all"). Returns 1 if the user enters
#                       nothing, so callers can abort cleanly.
ask_id() {
    local __var="$1" allow_all="${2:-}" __reply
    read -r -p "  Torrent ID${allow_all:+ (or 'all')}: " __reply
    [ -z "$__reply" ] && return 1
    if [ "$allow_all" = "allow_all" ] && [ "$__reply" = "all" ]; then
        printf -v "$__var" '%s' "all"; return 0
    fi
    if [[ "$__reply" =~ ^[0-9]+$ ]]; then
        printf -v "$__var" '%s' "$__reply"; return 0
    fi
    flag "Not a valid ID: $__reply"
    return 1
}

# confirm "Question"    Yes/no prompt. Returns 0 for yes, 1 for no/empty.
confirm() {
    local reply
    read -r -p "  $1 [y/N]: " reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Pager ─────────────────────────────────────────────────────────────────────
# pager <text>   Prints text directly if it fits, otherwise pipes through less
#                (-R keeps colours, -S chops wide lines, -X keeps the screen).
#                A tiny lesskey file makes Escape quit just like q.
pager() {
    local text="$1"
    local term_lines; term_lines=$(tput lines 2>/dev/null || echo 24)
    local text_lines; text_lines=$(echo -e "$text" | wc -l)

    if [ "$text_lines" -gt $(( term_lines - 6 )) ] && command -v less >/dev/null 2>&1; then
        local lesskey_file; lesskey_file=$(mktemp /tmp/tm_lesskey.XXXXXX)
        printf '\\e quit\n' > "$lesskey_file"
        echo -e "$text" | LESSKEY="$lesskey_file" less -RSX
        rm -f "$lesskey_file"
    else
        echo -e "$text"
    fi
}
