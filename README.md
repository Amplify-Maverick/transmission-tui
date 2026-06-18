# Transmission Daemon Manager

An interactive terminal tool for managing a remote `transmission-daemon` over SSH.
Arrow-key menus (or type a number), paste a magnet link to start a download, check
where the daemon is saving files, manage speed limits, run VPN/kill-switch health
checks, and control the systemd service.

The UI is modelled on the `sec-audit` tool: a banner, a single-ruled menu box with
a `❯` cursor on the selected row, arrow-key / number navigation, and a per-screen
action that prints the command it ran followed by short interpretive notes.

---

## Install

Copy the folder onto the VPS (or your workstation that can reach the daemon):

```bash
chmod +x transmission_manager.sh
./transmission_manager.sh
```

Requires `transmission-remote` (`sudo apt install transmission-cli`). A few system
checks (VPN, port binding, service control, reading `settings.json`) call `sudo`
themselves only where needed — you do **not** launch the whole tool with sudo.

---

## Configuration (environment variables, all optional)

| Variable | Purpose | Default |
|----------|---------|---------|
| `TR_AUTH` | `user:password` for the daemon RPC. If unset, you're prompted once at launch (session only). | prompted |
| `TR_HOST` | `host:port` of the daemon. | local daemon, default port |
| `DOWNLOAD_DIR` | Default download directory, used by the Retrieve menu. | `/var/lib/transmission-daemon/downloads` |
| `SETTINGS_JSON` | Path to `settings.json`. | `/etc/transmission-daemon/settings.json` |

To persist the password across SSH sessions (plaintext-readable by your user):

```bash
echo 'export TR_AUTH="transmission:yourpassword"' >> ~/.bashrc && source ~/.bashrc
```

The password is **never printed** to the screen — every transmission command shows
as `transmission-remote --auth *** <args>`, so it won't end up in your scrollback.

---

## Navigation

- **Arrow keys** — move the cursor
- **Type a number + Enter** — jump to an item
- **Enter** — open a category / run an action
- **q** — quit (restores your terminal exactly as it was)

## Menu map

```
Add a torrent          Paste a magnet link · Add a .torrent file by path
List & inspect         List all · Inspect one · Live view (5s) · Session stats
Control torrents       Start/stop one · Start/stop ALL · Verify data
Remove torrents        Remove (keep files) · Remove AND delete files
Download location      Live daemon dirs · A torrent's location · settings.json
Speed limits           Set down · Set up · Unlimited · Show current
VPN / network health   wg show · port binding · iptables · routing · restart · all
Daemon service         Status · Restart · Stop (+ pgrep check) · Show processes
Retrieve finished files  List the download dir · Build an scp command
Scan & inspect files   freshclam · clamscan file/dir/downloads · VirusTotal hash ·
                       verify hash · file+strings · peek in archive · flag exes
```

---

## Notes

- **Where do downloads go?** The *Download location* menu answers this three ways:
  the daemon's live in-memory directory (`-si`), a specific torrent's `Location:`
  (`-t <id> -i`), and the on-disk `download-dir` in `settings.json`. If the live
  value and the file disagree, the daemon hasn't reloaded — restart it.
- **Editing `settings.json`:** only edit it while the daemon is fully stopped.
  *Daemon service → Stop* runs the stop and then `pgrep` and tells you whether it's
  safe; editing while it runs lets the daemon overwrite your changes on its next save.
- **Retrieving files** runs *on your laptop*, not the VPS, so that screen builds the
  `scp` command for you to copy and run locally rather than executing it.
- **Scanning** offers to install ClamAV if it's missing and prompts to run `freshclam`
  before each scan (a scanner is only as good as its signatures). The VirusTotal
  option only computes and looks up the SHA-256 — it never uploads your file. The
  archive peek lists contents without extracting, and the executable flag catches
  runnable files (and double extensions like `movie.mp4.exe`) hiding in your downloads.

## Disclaimer

A convenience wrapper around `transmission-remote` and standard system tools. It
does not change `settings.json` for you, and destructive actions (remove-and-delete,
stop-all, tunnel restart) ask for confirmation first. Verify outputs with your own
judgment.
