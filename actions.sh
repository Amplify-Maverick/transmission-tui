#!/usr/bin/env bash
# tm/actions.sh — Leaf operations. Each mirrors the sec-audit "check" shape:
#   header → desc → run command(s) → (optional) notes → pause
# Sourced by transmission_manager.sh. Requires lib.sh.

# ── Add ───────────────────────────────────────────────────────────────────────

add_magnet() {
    header "Add a Magnet Link"
    desc "Paste a magnet link to start downloading immediately."
    echo -e "${DIM}  Right-click / paste works; the whole line is read as one value.${RESET}\n"
    local magnet
    ask magnet "Magnet link"
    echo
    if [ -z "$magnet" ]; then
        warn "Nothing pasted — cancelled."
        pause; return
    fi
    if [[ "$magnet" != magnet:\?* ]]; then
        warn "That doesn't look like a magnet link (should start with 'magnet:?')."
        confirm "Add it anyway?" || { pause; return; }
    fi
    run_tr -a "$magnet"
    analysis_header
    info "If it was accepted you'll see it in 'List all torrents' with a fresh ID."
    tip "New torrents start downloading right away unless the daemon is set to add paused."
    pause
}

add_torrent_file() {
    header "Add a .torrent File"
    desc "Add a torrent from a .torrent file already present on the VPS."
    echo -e "${DIM}  Get one onto the VPS first, e.g. from your laptop:${RESET}"
    echo -e "${DIM}    scp ~/Downloads/file.torrent ubuntu@silky-percentage:/tmp/${RESET}\n"
    local path
    ask path "Path to .torrent file"
    echo
    [ -z "$path" ] && { warn "Cancelled."; pause; return; }
    if [ ! -f "$path" ]; then
        flag "No file at: $path"
        tip "Double-check the path on the VPS (try: ls -l '$path')."
        pause; return
    fi
    run_tr -a "$path"
    pause
}

# ── List & inspect ─────────────────────────────────────────────────────────────

list_torrents() {
    header "All Torrents"
    desc "Summary of every torrent: ID, % done, ETA, speeds, ratio, status, name."
    run_tr -l
    analysis_header
    info "The number in the ID column is what every Control/Remove action asks for."
    pause
}

inspect_torrent() {
    header "Inspect One Torrent"
    desc "Full detail for a single torrent (state, peers, files, location, ratio)."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    run_tr -t "$id" -i
    pause
}

live_list() {
    header "Live-Refreshing List"
    desc "Refreshes the torrent list every 5 seconds. Press Ctrl-C to stop."
    echo -e "${DIM}  (Returns to the menu when you break out with Ctrl-C.)${RESET}\n"
    sleep 1
    # watch can't see the _tr function or $TR_AUTH unless we export an inline
    # command. Build a redacted-safe inline call; the password lives only in the
    # already-exported environment variable, not in the visible command string.
    local hostarg=""
    [ -n "$TR_HOST" ] && hostarg="$TR_HOST "
    # trap Ctrl-C locally so it only kills watch, not the whole app
    trap ' ' INT
    watch -n 5 "transmission-remote ${hostarg}--auth \"\$TR_AUTH\" -l"
    trap '_quit' INT
    pause
}

session_stats() {
    header "Session Statistics"
    desc "Cumulative totals, current speeds, and uptime for the daemon."
    run_tr -st
    pause
}

# ── Control ─────────────────────────────────────────────────────────────────

start_torrent() {
    header "Start a Torrent"
    desc "Resume a specific paused torrent."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    run_tr -t "$id" --start
    pause
}

stop_torrent() {
    header "Stop (Pause) a Torrent"
    desc "Pause a specific torrent without removing it."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    run_tr -t "$id" --stop
    pause
}

start_all() {
    header "Start ALL Torrents"
    desc "Resume every torrent in the list."
    confirm "Start all torrents?" || { warn "Cancelled."; pause; return; }
    echo
    run_tr -t all --start
    pause
}

stop_all() {
    header "Stop ALL Torrents"
    desc "Pause every torrent in the list."
    confirm "Stop all torrents?" || { warn "Cancelled."; pause; return; }
    echo
    run_tr -t all --stop
    pause
}

verify_torrent() {
    header "Verify a Torrent's Data"
    desc "Re-hash the downloaded data on disk to confirm it's intact."
    echo -e "${DIM}  Verification can take a while for large torrents.${RESET}"
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    run_tr -t "$id" -v
    pause
}

# ── Remove ─────────────────────────────────────────────────────────────────

remove_keep() {
    header "Remove Torrent (Keep Files)"
    desc "Remove the torrent from the list but leave the downloaded files on disk."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    confirm "Remove torrent $id from the list (files kept)?" || { warn "Cancelled."; pause; return; }
    echo
    run_tr -t "$id" -r
    pause
}

remove_delete() {
    header "Remove Torrent AND Delete Files"
    desc "Remove the torrent AND delete its downloaded data. This cannot be undone."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    flag "This will permanently delete the downloaded files for torrent $id."
    confirm "Are you sure?" || { warn "Cancelled."; pause; return; }
    echo
    run_tr -t "$id" --remove-and-delete
    pause
}

# ── Download location ─────────────────────────────────────────────────────────

loc_session() {
    header "Daemon Download Directories"
    desc "Where the running daemon currently saves files (its live, in-memory config)."
    run_tr -si
    analysis_header
    local info_out; info_out=$(_tr -si 2>/dev/null)
    local dl;   dl=$(echo "$info_out"   | grep -i 'Download directory' | head -1 | sed 's/^[[:space:]]*//')
    if [ -n "$dl" ]; then
        ok "$dl"
    else
        info "Look for the 'Download Directory' line in the output above."
    fi
    tip "This is the live value the daemon is actually using right now — it can differ"
    tip "from settings.json if the file was edited while the daemon was running."
    pause
}

loc_torrent() {
    header "A Torrent's Download Location"
    desc "The exact directory a specific torrent is saving into."
    run_tr -l
    local id
    if ! ask_id id; then warn "Cancelled."; pause; return; fi
    echo
    echo -e "${GREEN}\$ transmission-remote --auth *** -t $id -i  ${DIM}(location line)${RESET}"
    local out; out=$(_tr -t "$id" -i 2>&1)
    local loc; loc=$(echo "$out" | grep -i 'Location:' | sed 's/^[[:space:]]*//')
    echo
    if [ -n "$loc" ]; then
        ok "$loc"
    else
        warn "No 'Location:' line returned — is the ID correct?"
        echo "$out" | head -20
    fi
    pause
}

loc_settings() {
    header "download-dir in settings.json"
    desc "The on-disk configured download directory (and incomplete dir, if set)."
    echo -e "${DIM}  File: ${SETTINGS_JSON}${RESET}"
    echo -e "${DIM}  Reading is safe at any time. Only EDIT this file while the daemon is${RESET}"
    echo -e "${DIM}  fully stopped (see Daemon service → Stop) or changes get overwritten.${RESET}\n"
    if [ ! -r "$SETTINGS_JSON" ]; then
        run_sys "sudo grep -E '\"(download-dir|incomplete-dir|incomplete-dir-enabled)\"' '$SETTINGS_JSON'"
    else
        run_sys "grep -E '\"(download-dir|incomplete-dir|incomplete-dir-enabled)\"' '$SETTINGS_JSON'"
    fi
    analysis_header
    info "If this differs from the live value (Download location → Daemon directories),"
    info "the daemon hasn't reloaded the file. Restart it from the Daemon service menu."
    pause
}

# ── Speed limits ───────────────────────────────────────────────────────────

speed_down() {
    header "Set Download Limit"
    desc "Global download speed cap, in kilobytes per second."
    local kb
    ask kb "Download limit (KB/s)"
    echo
    [[ "$kb" =~ ^[0-9]+$ ]] || { flag "Enter a whole number of KB/s."; pause; return; }
    run_tr -D "$kb"
    ok "Download limit set to ${kb} KB/s."
    pause
}

speed_up() {
    header "Set Upload Limit"
    desc "Global upload speed cap, in kilobytes per second."
    local kb
    ask kb "Upload limit (KB/s)"
    echo
    [[ "$kb" =~ ^[0-9]+$ ]] || { flag "Enter a whole number of KB/s."; pause; return; }
    run_tr -U "$kb"
    ok "Upload limit set to ${kb} KB/s."
    pause
}

speed_unlimited() {
    header "Remove All Speed Limits"
    desc "Set both global download and upload limits to unlimited."
    confirm "Remove all speed limits?" || { warn "Cancelled."; pause; return; }
    echo
    run_tr -D 0
    run_tr -U 0
    ok "Limits removed — both directions unlimited."
    pause
}

speed_show() {
    header "Current Speed Limits"
    desc "Shows the daemon's configured limits as part of the session info."
    run_tr -si
    analysis_header
    info "Look for the 'Limits' / speed-limit lines in the output above."
    pause
}

# ── VPN / network health ─────────────────────────────────────────────────────

vpn_wg() {
    header "WireGuard Tunnel Status"
    desc "Confirms the Mullvad tunnel is up and recently completed a handshake."
    run_sys "sudo wg show"
    analysis_header
    local hs; hs=$(sudo wg show 2>/dev/null | grep -i 'latest handshake')
    if [ -n "$hs" ]; then
        ok "Tunnel has handshaked: $(echo "$hs" | sed 's/^[[:space:]]*//')"
    else
        flag "No handshake found — the tunnel may be down. Try 'Restart the Mullvad tunnel'."
    fi
    pause
}

vpn_port() {
    header "Transmission Peer-Port Binding"
    desc "The peer port must be bound to the tunnel IP, NOT 0.0.0.0 (which leaks)."
    run_sys "sudo ss -tlnp | grep -i transmission"
    analysis_header
    local bind; bind=$(sudo ss -tlnp 2>/dev/null | grep -i transmission)
    if echo "$bind" | grep -q '0\.0\.0\.0'; then
        flag "Bound to 0.0.0.0 — Transmission is listening on ALL interfaces."
        tip "This can expose traffic outside the tunnel. Bind it to the Mullvad IP."
    elif [ -n "$bind" ]; then
        ok "Bound to a specific address (not 0.0.0.0)."
    else
        info "No transmission listener found — is the daemon running?"
    fi
    pause
}

vpn_iptables() {
    header "Kill Switch (iptables OUTPUT)"
    desc "The kill-switch rules; the mullvad counters should climb during downloads."
    run_sys "sudo iptables -L OUTPUT -v -n"
    analysis_header
    info "Re-open this while a torrent is active — rising packet/byte counts on the"
    info "tunnel rules mean traffic is correctly leaving through the VPN."
    pause
}

vpn_routing() {
    header "Policy Routing for the Tunnel"
    desc "Confirms the routing rules and table 200 for the tunnel IP are intact."
    run_sys "ip rule show"
    run_sys "ip route show table 200"
    pause
}

vpn_restart() {
    header "Restart the Mullvad Tunnel"
    desc "Brings the WireGuard tunnel down and back up."
    flag "While the tunnel is down, traffic could leak unless the kill switch holds."
    confirm "Restart the Mullvad tunnel now?" || { warn "Cancelled."; pause; return; }
    echo
    run_sys "sudo wg-quick down mullvad"
    run_sys "sudo wg-quick up mullvad"
    analysis_header
    info "Re-check 'WireGuard tunnel status' to confirm a fresh handshake."
    pause
}

# ── Daemon service ─────────────────────────────────────────────────────────

daemon_status() {
    header "Daemon Service Status"
    desc "systemd status for transmission-daemon."
    run_sys "sudo systemctl status transmission-daemon --no-pager"
    pause
}

daemon_restart() {
    header "Restart Daemon"
    desc "Restart transmission-daemon (picks up a saved settings.json)."
    confirm "Restart transmission-daemon?" || { warn "Cancelled."; pause; return; }
    echo
    run_sys "sudo systemctl restart transmission-daemon"
    ok "Restart issued. Check status to confirm it came back up."
    pause
}

daemon_stop() {
    header "Stop Daemon"
    desc "Stop the daemon — required before safely editing settings.json."
    confirm "Stop transmission-daemon?" || { warn "Cancelled."; pause; return; }
    echo
    run_sys "sudo systemctl stop transmission-daemon"
    echo
    run_sys "pgrep -a transmission-daemon"
    analysis_header
    if pgrep -x transmission-daemon >/dev/null 2>&1; then
        flag "A transmission-daemon process is still running — do NOT edit settings.json yet."
        tip "Wait and re-check; editing while it runs lets the daemon overwrite your changes."
    else
        ok "No transmission-daemon process running — safe to edit settings.json now."
    fi
    pause
}

daemon_procs() {
    header "Daemon Processes"
    desc "Any running transmission-daemon processes, with their PIDs and arguments."
    run_sys "pgrep -a transmission-daemon"
    pause
}

# ── Retrieve finished files ──────────────────────────────────────────────────

retrieve_list() {
    header "Files in the Download Directory"
    desc "Lists what's in ${DOWNLOAD_DIR}."
    if [ -r "$DOWNLOAD_DIR" ]; then
        run_sys "ls -lh --group-directories-first '$DOWNLOAD_DIR'"
    else
        run_sys "sudo ls -lh --group-directories-first '$DOWNLOAD_DIR'"
    fi
    analysis_header
    info "Use the next option to build the scp command for pulling one of these down."
    pause
}

retrieve_scp() {
    header "Build an scp Command"
    desc "Generates the scp line to run ON YOUR LOCAL MACHINE to pull a file down."
    echo -e "${DIM}  scp copies from the VPS to your laptop, so it runs locally, not here.${RESET}\n"
    local fname dest user host
    ask fname "Filename in the download dir"
    [ -z "$fname" ] && { warn "Cancelled."; pause; return; }
    ask user  "VPS SSH user (e.g. ubuntu)"
    ask host  "VPS host/alias (e.g. silky-percentage)"
    ask dest  "Local destination (blank = ~/Downloads/)"
    [ -z "$dest" ] && dest="~/Downloads/"
    echo
    analysis_header
    info "Copy this and run it in a terminal on your laptop:"
    echo
    echo -e "  ${GREEN}scp ${user}@${host}:${DOWNLOAD_DIR}/${fname} ${dest}${RESET}"
    echo
    tip "Add -r for a folder, e.g. scp -r ${user}@${host}:${DOWNLOAD_DIR}/<folder> ${dest}"
    pause
}

# ── Scan & inspect files ──────────────────────────────────────────────────────
# Defensive triage for downloaded content: signature scanning (ClamAV), a
# privacy-preserving VirusTotal hash lookup, checksum verification, and static
# inspection. Mirrors how sec-audit's malware module offers to install its tools.

_ensure_clamav() {
    command -v clamscan >/dev/null 2>&1 && return 0
    warn "clamscan (ClamAV) is not installed."
    if confirm "Install it now with apt?"; then
        echo
        run_sys "sudo apt-get update && sudo apt-get install -y clamav"
        command -v clamscan >/dev/null 2>&1 && return 0
    fi
    info "Skipped. Install later with: sudo apt install clamav"
    return 1
}

_run_freshclam() {
    echo -e "${DIM}  freshclam pulls the latest signature database. A scanner is only as${RESET}"
    echo -e "${DIM}  good as its definitions — an out-of-date set waves known-bad files through.${RESET}"
    run "sudo freshclam"
    echo -e "${DIM}  (If it says the log is locked, the clamav-freshclam service already keeps${RESET}"
    echo -e "${DIM}   signatures current in the background — that's fine.)${RESET}"
}

scan_freshclam() {
    header "Update Signatures (freshclam)"
    desc "Refresh the ClamAV signature database before scanning."
    _ensure_clamav || { pause; return; }
    echo
    _run_freshclam
    pause
}

scan_file() {
    header "Scan a File (clamscan)"
    desc "Run ClamAV against a single file."
    _ensure_clamav || { pause; return; }
    local f; ask f "Path to file"
    [ -z "$f" ] && { warn "Cancelled."; pause; return; }
    [ -e "$f" ] || { flag "No such file: $f"; pause; return; }
    echo
    confirm "Update signatures (freshclam) first?" && { echo; _run_freshclam; echo; }
    run "clamscan '$f'"
    analysis_header
    info "A line ending in 'FOUND' means a signature matched; 'OK' is clean."
    pause
}

scan_dir() {
    header "Scan a Directory (clamscan -r)"
    desc "Recursively scan a directory, printing only infected files."
    _ensure_clamav || { pause; return; }
    local d; ask d "Directory to scan"
    [ -z "$d" ] && { warn "Cancelled."; pause; return; }
    [ -d "$d" ] || { flag "Not a directory: $d"; pause; return; }
    echo
    confirm "Update signatures (freshclam) first?" && { echo; _run_freshclam; echo; }
    info "Large trees take a while; clamscan loads ~1GB of signatures into RAM."
    run "clamscan -r --infected '$d'"
    analysis_header
    info "Only infected files are listed — no listed files means nothing matched."
    pause
}

scan_downloads() {
    header "Scan the Download Directory"
    desc "Recursively scan ${DOWNLOAD_DIR}, printing only infected files."
    _ensure_clamav || { pause; return; }
    echo
    confirm "Update signatures (freshclam) first?" && { echo; _run_freshclam; echo; }
    local SUDO=""; [ -r "$DOWNLOAD_DIR" ] || SUDO="sudo "
    run "${SUDO}clamscan -r --infected '$DOWNLOAD_DIR'"
    analysis_header
    info "Only infected files are listed — no listed files means nothing matched."
    pause
}

scan_vt_hash() {
    header "VirusTotal Hash Lookup"
    desc "Compute a file's SHA-256 and look it up on VirusTotal — without uploading."
    echo -e "${DIM}  Checking the hash first is the privacy-preserving move: if VT has seen the${RESET}"
    echo -e "${DIM}  file before, you get ~70 engines' verdicts without sending the file anywhere.${RESET}\n"
    local f; ask f "Path to file"
    [ -z "$f" ] && { warn "Cancelled."; pause; return; }
    [ -f "$f" ] || { flag "No such file: $f"; pause; return; }
    echo
    local sum; sum=$(sha256sum "$f" | awk '{print $1}')
    ok "SHA-256: $sum"
    echo
    info "Open this (or paste the hash at virustotal.com):"
    echo -e "  ${GREEN}https://www.virustotal.com/gui/file/${sum}${RESET}"
    echo
    warn "Only UPLOAD the file itself if the hash is unknown AND it holds nothing sensitive"
    warn "— uploads become visible to VirusTotal's subscribers."
    pause
}

scan_verify_hash() {
    header "Verify a File Against a Known Hash"
    desc "Compute a checksum and compare it to a hash you were given (e.g. an ISO's)."
    local f; ask f "Path to file"
    [ -z "$f" ] && { warn "Cancelled."; pause; return; }
    [ -f "$f" ] || { flag "No such file: $f"; pause; return; }
    local expected; ask expected "Expected hash (md5/sha1/sha256)"
    [ -z "$expected" ] && { warn "Cancelled."; pause; return; }
    expected=$(echo "$expected" | tr 'A-Z' 'a-z' | tr -d '[:space:]')
    local algo actual
    case "${#expected}" in
        32) algo="md5";    actual=$(md5sum "$f"    | awk '{print $1}') ;;
        40) algo="sha1";   actual=$(sha1sum "$f"   | awk '{print $1}') ;;
        64) algo="sha256"; actual=$(sha256sum "$f" | awk '{print $1}') ;;
        *)  flag "Hash length ${#expected} matches none of md5(32)/sha1(40)/sha256(64)."; pause; return ;;
    esac
    echo
    info "Algorithm (by length): $algo"
    info "Expected: $expected"
    info "Actual:   $actual"
    analysis_header
    if [ "$expected" = "$actual" ]; then
        ok "MATCH — the file matches the published $algo hash."
    else
        flag "MISMATCH — this file does NOT match. It may be corrupted or tampered with."
        tip "Re-download from a trusted source; don't trust this copy."
    fi
    pause
}

scan_static() {
    header "Static Inspection (file + strings)"
    desc "Identify a file's real type and pull readable strings (URLs, IPs, commands)."
    local f; ask f "Path to file"
    [ -z "$f" ] && { warn "Cancelled."; pause; return; }
    [ -e "$f" ] || { flag "No such file: $f"; pause; return; }
    echo
    run "file '$f'"
    analysis_header
    info "The extension can lie — 'file' reads the actual content (magic bytes)."
    echo
    if confirm "Show readable strings now (paged)?"; then
        echo
        echo -e "${GREEN}\$ strings '$f' | less${RESET}"
        local out; out=$(strings "$f" 2>/dev/null)
        pager "$out"
    fi
    pause
}

# _list_archive PATH — list an archive's contents without extracting.
_list_archive() {
    local f="$1" t; t=$(file -b "$f" 2>/dev/null)
    if echo "$t" | grep -qiE 'tar archive|POSIX tar|gzip compressed|bzip2 compressed|XZ compressed|Zstandard'; then
        run "tar -tvf '$f'"; return
    fi
    if echo "$t" | grep -qi 'Zip archive'; then
        if   command -v unzip  >/dev/null 2>&1; then run "unzip -l '$f'"
        elif command -v bsdtar >/dev/null 2>&1; then run "bsdtar -tvf '$f'"
        else warn "Install 'unzip' (sudo apt install unzip) to list zip contents."; fi
        return
    fi
    if echo "$t" | grep -qi '7-zip'; then
        if command -v 7z >/dev/null 2>&1; then run "7z l '$f'"
        else warn "Install p7zip-full (sudo apt install p7zip-full) to list 7z contents."; fi
        return
    fi
    if echo "$t" | grep -qi 'RAR archive'; then
        if   command -v unrar >/dev/null 2>&1; then run "unrar l '$f'"
        elif command -v 7z    >/dev/null 2>&1; then run "7z l '$f'"
        else warn "Install 'unrar' or p7zip-full to list RAR contents."; fi
        return
    fi
    warn "Not a recognised archive: $t"
    info "Inspect it directly:  file '$f'   |   strings '$f' | less"
}

scan_archive() {
    header "Peek Inside an Archive (no extract)"
    desc "List an archive's contents WITHOUT unpacking it — safe triage."
    echo -e "${DIM}  Listing never runs anything; extracting can drop files onto disk.${RESET}\n"
    local f; ask f "Path to archive"
    [ -z "$f" ] && { warn "Cancelled."; pause; return; }
    [ -f "$f" ] || { flag "No such file: $f"; pause; return; }
    echo
    run "file '$f'"
    _list_archive "$f"
    analysis_header
    info "Watch for executables, scripts, or double extensions hiding among media files."
    pause
}

scan_executables() {
    header "Flag Executables & Scripts in Downloads"
    desc "Media torrents shouldn't contain runnable files — flag any that look executable."
    local base="$DOWNLOAD_DIR"
    local SUDO=""; [ -r "$base" ] || SUDO="sudo "
    echo -e "${DIM}  Scanning: ${base}${RESET}\n"

    echo -e "${GREEN}\$ find ... (suspicious extensions, incl. double extensions)${RESET}"
    local ext_re='\.(exe|scr|bat|cmd|com|pif|vbs|jse?|ps1|msi|jar|lnk|dll|app|apk)$'
    local ext_hits; ext_hits=$(eval "${SUDO}find '$base' -type f 2>/dev/null" | grep -iE "$ext_re")

    echo -e "${GREEN}\$ file <each file> | grep ELF/PE/Mach-O/script${RESET}\n"
    local type_hits; type_hits=$(eval "${SUDO}find '$base' -type f -exec file {} + 2>/dev/null" \
        | grep -Ei ': *(ELF |PE32|Mach-O|MS-DOS executable|.*shell script|.*Python script|.*Perl script)')

    analysis_header
    if [ -z "$ext_hits" ] && [ -z "$type_hits" ]; then
        ok "No executables, scripts, or suspicious extensions in the download directory."
    else
        if [ -n "$ext_hits" ]; then
            flag "Files with executable/script extensions:"
            while IFS= read -r l; do [ -n "$l" ] && flag "  $l"; done <<< "$ext_hits"
        fi
        if [ -n "$type_hits" ]; then
            warn "Files whose CONTENT is executable/script (the name may be disguised):"
            while IFS= read -r l; do [ -n "$l" ] && warn "  $l"; done <<< "$type_hits"
        fi
        tip "Don't run these. Scan them (clamscan / VirusTotal) and inspect with file + strings."
    fi
    pause
}
