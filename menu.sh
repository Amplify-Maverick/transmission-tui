#!/usr/bin/env bash
# tm/menu.sh — Two-level menu: categories → submenus.
# Sourced by transmission_manager.sh after lib.sh and actions.sh.
# Box drawing and the arrow-key / number input loop mirror the sec-audit tool.

# ── Category & submenu definitions ───────────────────────────────────────────

MAIN_ITEMS=(
    "Add a torrent"
    "List & inspect torrents"
    "Control torrents"
    "Remove torrents"
    "Download location"
    "Speed limits"
    "VPN / network health"
    "Daemon service"
    "Retrieve finished files"
    "Scan & inspect files"
    "Quit"
)

SUBMENU_ADD=(
    "Paste a magnet link"
    "Add a .torrent file (path on the VPS)"
    "← Back"
)

SUBMENU_LIST=(
    "List all torrents"
    "Inspect one torrent (detailed)"
    "Live-refreshing list (every 5s)"
    "Session statistics"
    "← Back"
)

SUBMENU_CONTROL=(
    "Start a torrent"
    "Stop (pause) a torrent"
    "Start ALL torrents"
    "Stop ALL torrents"
    "Verify a torrent's data on disk"
    "← Back"
)

SUBMENU_REMOVE=(
    "Remove torrent (keep downloaded files)"
    "Remove torrent AND delete files"
    "← Back"
)

SUBMENU_LOCATION=(
    "Daemon download directories (live session)"
    "A specific torrent's location"
    "download-dir from settings.json"
    "← Back"
)

SUBMENU_SPEED=(
    "Set download limit (KB/s)"
    "Set upload limit (KB/s)"
    "Remove all limits (unlimited)"
    "Show current limits"
    "← Back"
)

SUBMENU_VPN=(
    "WireGuard tunnel status"
    "Transmission peer-port binding"
    "Kill switch (iptables OUTPUT) rules"
    "Policy routing for the tunnel"
    "Restart the Mullvad tunnel"
    "Run all VPN health checks"
    "← Back"
)

SUBMENU_DAEMON=(
    "Service status"
    "Restart daemon"
    "Stop daemon (with running-process check)"
    "Show daemon processes"
    "← Back"
)

SUBMENU_RETRIEVE=(
    "List files in the download directory"
    "Build an scp command for a finished file"
    "← Back"
)

SUBMENU_SCAN=(
    "Update signatures (freshclam)"
    "Scan a file (clamscan)"
    "Scan a directory (clamscan -r)"
    "Scan the download directory"
    "VirusTotal hash lookup (no upload)"
    "Verify a file against a known hash"
    "Static inspection (file + strings)"
    "Peek inside an archive (no extract)"
    "Flag executables/scripts in downloads"
    "← Back"
)

# ── Clean exit ───────────────────────────────────────────────────────────────
_quit() {
    tput cnorm   # restore cursor
    tput rmcup   # restore original screen — terminal looks untouched on exit
    exit 0
}

# ── Box drawing ───────────────────────────────────────────────────────────────
_compute_box_width() {
    local max=0 i=1
    for item in "$@"; do
        local plain="  ${i}.   ${item}  "
        (( ${#plain} > max )) && max=${#plain}
        (( i++ ))
    done
    BOX_INNER=$max
}

_hrule() {
    printf '%s' "$1"
    printf '─%.0s' $(seq 1 "$BOX_INNER")
    printf '%s\n' "$3"
}

_box_row() {
    # $1 = plain string (for width), $2 = colored string (printed)
    local pad=$(( BOX_INNER - ${#1} ))
    printf '│'; printf '%b' "$2"; printf '%*s' "$pad" ''; printf '│\n'
}

# ── Generic menu renderer ─────────────────────────────────────────────────────
# draw_menu FIRST|"" TITLE SELECTED_IDX ITEM [ITEM ...]
MENU_LINE_COUNT=0

draw_menu() {
    local first_draw="$1" title="$2" sel="$3"
    shift 3
    local items=("$@")

    [ "$first_draw" = "first" ] && clear || printf '\033[%dA' "$MENU_LINE_COUNT"

    _compute_box_width "${items[@]}"

    local lines=0
    _line() { printf '\033[2K'; printf '%b\n' "$1"; (( lines++ )); }

    # ── Banner ──
    _line "${BOLD}"
    _line "  ╔══════════════════════════════════════════╗"
    _line "  ║       Transmission Daemon Manager        ║"
    _line "  ╚══════════════════════════════════════════╝"
    _line "${RESET}"

    # ── Connection line + safety note ──
    if [ -n "$TR_HOST" ]; then
        _line "  ${DIM}Daemon: ${TR_HOST}${RESET}"
    else
        _line "  ${DIM}Daemon: local (default host:port)${RESET}"
    fi
    _line "  ${AMBER}Check the VPN tunnel is up before downloading (VPN menu).${RESET}"
    _line ""

    # ── Subtitle (category name, empty on main menu) ──
    if [ -n "$title" ]; then
        _line "  ${BOLD}${CYAN}${title}${RESET}"
        _line ""
    fi

    # ── Box ──
    _line "  $(_hrule ┌ ─ ┐)"

    local i
    for i in "${!items[@]}"; do
        local item="${items[$i]}"
        local num=$(( i + 1 ))
        if [ "$i" -eq "$sel" ]; then
            _line "  $(_box_row "  ${num}. ❯ ${item}  " "${CYAN}${BOLD}  ${num}. ❯ ${item}  ${RESET}")"
        else
            _line "  $(_box_row "  ${num}.   ${item}  " "${DIM}  ${num}.${RESET}   ${item}  ")"
        fi
    done

    _line "  $(_hrule └ ─ ┘)"
    _line ""
    _line "  ${DIM}↑ ↓ arrow keys  or  type a number + Enter  │  q to quit${RESET}"

    MENU_LINE_COUNT=$lines
}

# ── Generic submenu runner ────────────────────────────────────────────────────
run_submenu() {
    local title="$1"; shift
    local items=("$@")
    local count=${#items[@]}
    local sel=0
    local num_buf=""

    tput civis
    draw_menu first "$title" "$sel" "${items[@]}"

    while true; do
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            key="${key}${rest}"
        fi

        case "$key" in
            $'\x1b[A'|$'\x1b[OA')   # up
                num_buf=""
                (( sel > 0 )) && (( sel-- ))
                draw_menu "" "$title" "$sel" "${items[@]}" ;;
            $'\x1b[B'|$'\x1b[OB')   # down
                num_buf=""
                (( sel < count - 1 )) && (( sel++ ))
                draw_menu "" "$title" "$sel" "${items[@]}" ;;
            [0-9])
                local tentative="${num_buf}${key}"
                if [ "$tentative" -le "$count" ] 2>/dev/null && [ "$tentative" -ge 1 ]; then
                    num_buf="$tentative"
                    sel=$(( num_buf - 1 ))
                    draw_menu "" "$title" "$sel" "${items[@]}"
                fi ;;
            $'\x7f'|$'\x08')         # backspace
                if [ -n "$num_buf" ]; then
                    num_buf="${num_buf%?}"
                    if [ -n "$num_buf" ] && [ "$num_buf" -ge 1 ] && [ "$num_buf" -le "$count" ] 2>/dev/null; then
                        sel=$(( num_buf - 1 ))
                    fi
                    draw_menu "" "$title" "$sel" "${items[@]}"
                fi ;;
            '')                       # enter
                num_buf=""
                local chosen="${items[$sel]}"
                if [ "$chosen" = "← Back" ]; then
                    tput cnorm
                    return
                fi
                tput cnorm
                submenu_dispatch "$chosen"
                tput civis
                draw_menu first "$title" "$sel" "${items[@]}" ;;
            q|Q)
                _quit ;;
        esac
    done
}

# ── Submenu dispatch ──────────────────────────────────────────────────────────
submenu_dispatch() {
    case "$1" in
        # Add
        "Paste a magnet link")                          add_magnet ;;
        "Add a .torrent file (path on the VPS)")        add_torrent_file ;;
        # List & inspect
        "List all torrents")                            list_torrents ;;
        "Inspect one torrent (detailed)")               inspect_torrent ;;
        "Live-refreshing list (every 5s)")              live_list ;;
        "Session statistics")                           session_stats ;;
        # Control
        "Start a torrent")                              start_torrent ;;
        "Stop (pause) a torrent")                       stop_torrent ;;
        "Start ALL torrents")                           start_all ;;
        "Stop ALL torrents")                            stop_all ;;
        "Verify a torrent's data on disk")              verify_torrent ;;
        # Remove
        "Remove torrent (keep downloaded files)")       remove_keep ;;
        "Remove torrent AND delete files")              remove_delete ;;
        # Location
        "Daemon download directories (live session)")   loc_session ;;
        "A specific torrent's location")                loc_torrent ;;
        "download-dir from settings.json")              loc_settings ;;
        # Speed
        "Set download limit (KB/s)")                    speed_down ;;
        "Set upload limit (KB/s)")                      speed_up ;;
        "Remove all limits (unlimited)")                speed_unlimited ;;
        "Show current limits")                          speed_show ;;
        # VPN
        "WireGuard tunnel status")                      vpn_wg ;;
        "Transmission peer-port binding")               vpn_port ;;
        "Kill switch (iptables OUTPUT) rules")          vpn_iptables ;;
        "Policy routing for the tunnel")                vpn_routing ;;
        "Restart the Mullvad tunnel")                   vpn_restart ;;
        "Run all VPN health checks")
            vpn_wg; vpn_port; vpn_iptables; vpn_routing ;;
        # Daemon
        "Service status")                               daemon_status ;;
        "Restart daemon")                               daemon_restart ;;
        "Stop daemon (with running-process check)")     daemon_stop ;;
        "Show daemon processes")                        daemon_procs ;;
        # Retrieve
        "List files in the download directory")         retrieve_list ;;
        "Build an scp command for a finished file")     retrieve_scp ;;
        # Scan & inspect
        "Update signatures (freshclam)")                scan_freshclam ;;
        "Scan a file (clamscan)")                       scan_file ;;
        "Scan a directory (clamscan -r)")               scan_dir ;;
        "Scan the download directory")                  scan_downloads ;;
        "VirusTotal hash lookup (no upload)")           scan_vt_hash ;;
        "Verify a file against a known hash")           scan_verify_hash ;;
        "Static inspection (file + strings)")           scan_static ;;
        "Peek inside an archive (no extract)")          scan_archive ;;
        "Flag executables/scripts in downloads")        scan_executables ;;
    esac
}

# ── Main menu runner ──────────────────────────────────────────────────────────
run_menu() {
    tput smcup  # alternate screen buffer
    tput civis
    trap '_quit' EXIT INT TERM

    local sel=0
    local count=${#MAIN_ITEMS[@]}
    local num_buf=""

    draw_menu first "" "$sel" "${MAIN_ITEMS[@]}"

    while true; do
        IFS= read -rsn1 key
        if [[ "$key" == $'\x1b' ]]; then
            read -rsn2 -t 0.1 rest
            key="${key}${rest}"
        fi

        case "$key" in
            $'\x1b[A'|$'\x1b[OA')
                num_buf=""
                (( sel > 0 )) && (( sel-- ))
                draw_menu "" "" "$sel" "${MAIN_ITEMS[@]}" ;;
            $'\x1b[B'|$'\x1b[OB')
                num_buf=""
                (( sel < count - 1 )) && (( sel++ ))
                draw_menu "" "" "$sel" "${MAIN_ITEMS[@]}" ;;
            [0-9])
                local tentative="${num_buf}${key}"
                if [ "$tentative" -le "$count" ] 2>/dev/null && [ "$tentative" -ge 1 ]; then
                    num_buf="$tentative"
                    sel=$(( num_buf - 1 ))
                    draw_menu "" "" "$sel" "${MAIN_ITEMS[@]}"
                fi ;;
            $'\x7f'|$'\x08')
                if [ -n "$num_buf" ]; then
                    num_buf="${num_buf%?}"
                    if [ -n "$num_buf" ] && [ "$num_buf" -ge 1 ] && [ "$num_buf" -le "$count" ] 2>/dev/null; then
                        sel=$(( num_buf - 1 ))
                    fi
                    draw_menu "" "" "$sel" "${MAIN_ITEMS[@]}"
                fi ;;
            '')
                num_buf=""
                case "${MAIN_ITEMS[$sel]}" in
                    "Add a torrent")
                        tput cnorm; run_submenu "Add a torrent" "${SUBMENU_ADD[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "List & inspect torrents")
                        tput cnorm; run_submenu "List & inspect torrents" "${SUBMENU_LIST[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Control torrents")
                        tput cnorm; run_submenu "Control torrents" "${SUBMENU_CONTROL[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Remove torrents")
                        tput cnorm; run_submenu "Remove torrents" "${SUBMENU_REMOVE[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Download location")
                        tput cnorm; run_submenu "Download location" "${SUBMENU_LOCATION[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Speed limits")
                        tput cnorm; run_submenu "Speed limits" "${SUBMENU_SPEED[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "VPN / network health")
                        tput cnorm; run_submenu "VPN / network health" "${SUBMENU_VPN[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Daemon service")
                        tput cnorm; run_submenu "Daemon service" "${SUBMENU_DAEMON[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Retrieve finished files")
                        tput cnorm; run_submenu "Retrieve finished files" "${SUBMENU_RETRIEVE[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Scan & inspect files")
                        tput cnorm; run_submenu "Scan & inspect files" "${SUBMENU_SCAN[@]}"
                        tput civis; draw_menu first "" "$sel" "${MAIN_ITEMS[@]}" ;;
                    "Quit")
                        _quit ;;
                esac ;;
            q|Q)
                _quit ;;
        esac
    done
}
