<p align="center">
  <pre>
     █████╗ ██████╗ ███████╗██╗  ██╗██╗███████╗██╗     ██████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗
    ███████║██║  ██║███████╗███████║██║█████╗  ██║     ██║  ██║
    ██╔══██║██║  ██║╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║
    ██║  ██║██████╔╝███████║██║  ██║██║███████╗███████╗██████╔╝
    ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝
  </pre>
</p>

<p align="center">
  <strong>System-level ad blocker for your entire machine.</strong><br>
  No browser extensions. No VPN. Just your hosts file.
</p>

<p align="center">
  <a href="#installation"><img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux%20%7C%20Windows-blue?style=flat-square" alt="Platform"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="License"></a>
  <a href="#"><img src="https://img.shields.io/badge/python-3.7%2B-yellow?style=flat-square" alt="Python"></a>
  <a href="#"><img src="https://img.shields.io/badge/zero-dependencies-orange?style=flat-square" alt="Dependencies"></a>
</p>

---

## What is CliShield?

**CliShield** is a lightweight CLI tool that blocks ads, trackers, and malware domains across your entire system by managing your operating system's hosts file. Every application — browsers, apps, games — benefits automatically. No browser extension required.

---

## How It Works

```
┌──────────────────────────────────────────────────────────────────┐
│                        Your Machine                              │
│                                                                  │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐   │
│   │ Browser  │   │  App #1  │   │  App #2  │   │  Game    │   │
│   └────┬─────┘   └────┬─────┘   └────┬─────┘   └────┬─────┘   │
│        │              │              │              │           │
│        └──────────────┴──────┬───────┴──────────────┘           │
│                              │                                   │
│                              ▼                                   │
│                    ┌──────────────────┐                          │
│                    │   /etc/hosts     │  ◄── CliShield writes     │
│                    │  (hosts file)    │      blocked domains     │
│                    └────────┬─────────┘      as 0.0.0.0         │
│                             │                                    │
│              ┌──────────────┴──────────────┐                    │
│              ▼                             ▼                    │
│     ┌─────────────────┐          ┌─────────────────┐           │
│     │  Blocked domain │          │ Allowed domain  │           │
│     │  → 0.0.0.0      │          │ → DNS lookup    │           │
│     │  (request dies) │          │ → loads normally│           │
│     └─────────────────┘          └─────────────────┘           │
└──────────────────────────────────────────────────────────────────┘
```

CliShield merges multiple community-maintained blocklists into your hosts file, redirecting known ad/tracking/malware domains to `0.0.0.0` so requests to them silently fail.

---

## Installation

### Homebrew (macOS / Linux)

```bash
brew tap USER/clishield
brew install clishield
sudo clishield activate
```

### One-Liner (macOS / Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/USER/clishield/main/install.sh | sudo bash
```

### Manual Install (macOS / Linux)

```bash
git clone https://github.com/USER/clishield.git
cd clishield
sudo bash install.sh
```

### Windows (PowerShell as Administrator)

```powershell
git clone https://github.com/USER/clishield.git
cd clishield
.\install.ps1
```

### Requirements

| Requirement | Details            |
|-------------|--------------------|
| Python      | 3.7 or later       |
| Privileges  | root / admin       |
| Dependencies| None (stdlib only)  |

---

## Usage

All commands that modify the hosts file require `sudo` (macOS/Linux) or an Administrator shell (Windows).

### Core Commands

```bash
# Activate ad blocking
sudo clishield activate

# Deactivate (restore original hosts file)
sudo clishield deactivate

# Check current status
clishield status

# Update blocklists from sources
sudo clishield update
```

### Whitelist Management

```bash
# Add a domain to the whitelist
sudo clishield whitelist add example.com

# Remove a domain from the whitelist
sudo clishield whitelist remove example.com

# List all whitelisted domains
clishield whitelist list
```

### Blocklist Sources

```bash
# List configured sources
clishield sources list

# Enable a source
clishield sources enable "AdGuard DNS Filter"

# Disable a source
clishield sources disable "Dan Pollock Hosts"
```

### Other Commands

```bash
# Show version
clishield --version

# Show help
clishield --help

# Count blocked domains
clishield stats
```

---

## Configuration

### Config Directory

CliShield stores its configuration in `~/.clishield/`:

```
~/.clishield/
├── sources.json       # Blocklist source configuration
├── whitelist.txt      # Your whitelisted domains (one per line)
├── hosts.backup       # Backup of your original hosts file
└── update.log         # Auto-update log
```

### Blocklist Sources (`sources.json`)

The default configuration includes four well-known community blocklists:

| Source                          | Category       | Domains |
|---------------------------------|---------------|---------|
| Steven Black Unified Hosts      | ads + malware | ~80k   |
| AdGuard DNS Filter              | ads           | ~50k   |
| Peter Lowe Ad & Tracking List   | ads + tracking| ~3k    |
| Dan Pollock Hosts               | ads + tracking| ~15k   |

You can add your own sources by editing `~/.clishield/sources.json`:

```json
{
  "name": "My Custom List",
  "url": "https://example.com/blocklist.txt",
  "category": "custom",
  "enabled": true
}
```

### Whitelist

If a blocked domain is breaking a site you need, whitelist it:

```bash
sudo clishield whitelist add cdn.example.com
sudo clishield update
```

The whitelist is stored in `~/.clishield/whitelist.txt` — one domain per line. You can edit it directly.

---

## Limitations

CliShield is transparent about what it **cannot** block:

| Scenario | Can Block? | Why |
|---|---|---|
| Web banner ads | ✅ Yes | Served from known ad domains |
| Tracking pixels | ✅ Yes | Third-party tracker domains |
| Malware domains | ✅ Yes | Known malicious hostnames |
| Pop-up/pop-under ads | ✅ Yes | Usually third-party domains |
| **YouTube in-stream ads** | ❌ No | Served from `*.googlevideo.com` — same domain as actual video content |
| **Spotify audio ads** | ❌ No | Served inline via the Spotify CDN |
| **Facebook/Instagram in-feed ads** | ❌ No | Served from first-party domains |
| **Hulu/Peacock streaming ads** | ❌ No | Delivered from the same CDN as content |
| Ads on HTTPS sites using DoH | ⚠️ Partial | Apps using DNS-over-HTTPS bypass the hosts file |

**Why?** Hosts-file blocking works at the domain level. When ads are served from the *same domain* as legitimate content (first-party ads), there is no way to block them without also breaking the service.

> **Tip:** For YouTube ad blocking, consider a browser extension like [uBlock Origin](https://ublockorigin.com/) alongside CliShield.

---

## Automatic Updates

The installer sets up a weekly auto-update job:

- **macOS:** `launchd` agent — runs every Sunday at 04:00
- **Linux:** `cron` job — runs every Sunday at 04:00
- **Windows:** Task Scheduler — runs every Sunday at 04:00

Logs are written to `~/.clishield/update.log`.

To update manually at any time:

```bash
sudo clishield update
```

---

## Uninstalling

### macOS / Linux

```bash
sudo bash uninstall.sh
```

Or manually:

```bash
sudo clishield deactivate
sudo rm /usr/local/bin/clishield
rm -rf ~/.clishield
# macOS: also remove ~/Library/LaunchAgents/com.clishield.update.plist
```

### Homebrew

```bash
sudo clishield deactivate
brew uninstall clishield
```

### Windows (Administrator PowerShell)

```powershell
clishield deactivate
Remove-Item "$env:ProgramFiles\clishield" -Recurse -Force
Remove-Item "$env:USERPROFILE\.clishield" -Recurse -Force
Unregister-ScheduledTask -TaskName "CliShield Weekly Update" -Confirm:$false
# Remove from PATH manually via System Properties → Environment Variables
```

---

## Contributing

Contributions are welcome! Here's how to get started:

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/my-feature`
3. **Commit** your changes: `git commit -m 'Add my feature'`
4. **Push** to the branch: `git push origin feature/my-feature`
5. **Open** a Pull Request

### Development Setup

```bash
git clone https://github.com/USER/clishield.git
cd clishield
# The clishield script is a standalone Python file — no build step needed.
# Test locally:
sudo python3 clishield activate
```

### Guidelines

- Keep it zero-dependency (Python stdlib only)
- Test on macOS, Linux, and Windows
- Update the README if you add new commands
- Be kind in code reviews

---

## License

[MIT](LICENSE) © 2024–2026 CliShield Contributors

---

<p align="center">
  <sub>Made with ☕ and a mass contempt for tracking pixels.</sub>
</p>
