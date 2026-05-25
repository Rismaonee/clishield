#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  AdShield Installer — macOS / Linux
#  Safe to run multiple times (idempotent).
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ── Helpers ───────────────────────────────────────────────────
info()    { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[  OK]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()    { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

# ── Banner ────────────────────────────────────────────────────
banner() {
    printf "${CYAN}${BOLD}"
    cat << 'EOF'

     █████╗ ██████╗ ███████╗██╗  ██╗██╗███████╗██╗     ██████╗
    ██╔══██╗██╔══██╗██╔════╝██║  ██║██║██╔════╝██║     ██╔══██╗
    ███████║██║  ██║███████╗███████║██║█████╗  ██║     ██║  ██║
    ██╔══██║██║  ██║╚════██║██╔══██║██║██╔══╝  ██║     ██║  ██║
    ██║  ██║██████╔╝███████║██║  ██║██║███████╗███████╗██████╔╝
    ╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═════╝

    System-level ad blocker for your entire machine.

EOF
    printf "${NC}"
}

# ── Configuration ─────────────────────────────────────────────
INSTALL_BIN="/usr/local/bin/adshield"
CONFIG_DIR="${HOME}/.adshield"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHD_LABEL="com.adshield.update"
LAUNCHD_PLIST="${HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

# ── Main ──────────────────────────────────────────────────────
banner

# 1. Check for root / sudo
if [[ $EUID -ne 0 ]]; then
    fail "This installer must be run as root.  Try:  sudo bash install.sh"
fi

# 2. Check for Python 3
info "Checking for Python 3…"
if command -v python3 &>/dev/null; then
    PY_VERSION="$(python3 --version 2>&1)"
    success "Found ${PY_VERSION}"
else
    fail "Python 3 is required but not found. Install it first: https://www.python.org/downloads/"
fi

# 3. Verify the adshield script exists next to this installer
if [[ ! -f "${SCRIPT_DIR}/adshield" ]]; then
    fail "Cannot find 'adshield' script in ${SCRIPT_DIR}. Make sure it is in the same directory as install.sh."
fi

# 4. Copy to /usr/local/bin
info "Installing adshield to ${INSTALL_BIN}…"
mkdir -p "$(dirname "${INSTALL_BIN}")"
cp -f "${SCRIPT_DIR}/adshield" "${INSTALL_BIN}"
chmod +x "${INSTALL_BIN}"
success "Installed ${INSTALL_BIN}"

# 5. Create config directory
REAL_HOME="${SUDO_USER:+$(eval echo "~${SUDO_USER}")}"
REAL_HOME="${REAL_HOME:-$HOME}"
CONFIG_DIR="${REAL_HOME}/.adshield"

info "Creating config directory at ${CONFIG_DIR}…"
mkdir -p "${CONFIG_DIR}"

# Copy default sources.json if it doesn't already exist
if [[ -f "${SCRIPT_DIR}/sources.json" ]] && [[ ! -f "${CONFIG_DIR}/sources.json" ]]; then
    cp "${SCRIPT_DIR}/sources.json" "${CONFIG_DIR}/sources.json"
    success "Copied default sources.json"
elif [[ -f "${CONFIG_DIR}/sources.json" ]]; then
    warn "sources.json already exists — keeping your version."
else
    warn "No sources.json found in ${SCRIPT_DIR}; skipping."
fi

# Fix ownership so the real user (not root) owns the config
if [[ -n "${SUDO_USER:-}" ]]; then
    chown -R "${SUDO_USER}" "${CONFIG_DIR}"
fi

success "Config directory ready: ${CONFIG_DIR}"

# 6. Activate ad blocking
info "Activating AdShield…"
if "${INSTALL_BIN}" activate; then
    success "AdShield is now active!"
else
    warn "Activation returned a non-zero exit code. You can retry with: sudo adshield activate"
fi

# 7. Set up automatic weekly updates (platform-specific)
info "Setting up weekly auto-update…"

setup_launchd() {
    local plist_dir
    plist_dir="$(dirname "${LAUNCHD_PLIST}")"
    mkdir -p "${plist_dir}"

    cat > "${LAUNCHD_PLIST}" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${INSTALL_BIN}</string>
        <string>update</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>0</integer>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>${CONFIG_DIR}/update.log</string>
    <key>StandardErrorPath</key>
    <string>${CONFIG_DIR}/update.log</string>
</dict>
</plist>
PLIST

    if [[ -n "${SUDO_USER:-}" ]]; then
        chown "${SUDO_USER}" "${LAUNCHD_PLIST}"
    fi

    # Unload first (ignore errors if not loaded)
    launchctl unload "${LAUNCHD_PLIST}" 2>/dev/null || true
    launchctl load "${LAUNCHD_PLIST}" 2>/dev/null || true
    success "Registered launchd job: ${LAUNCHD_LABEL} (Sundays at 04:00)"
}

setup_cron() {
    local cron_job="0 4 * * 0 ${INSTALL_BIN} update >> ${CONFIG_DIR}/update.log 2>&1"
    local cron_user="${SUDO_USER:-root}"

    # Remove any existing adshield cron entry, then append
    (crontab -u "${cron_user}" -l 2>/dev/null | grep -v "${INSTALL_BIN}" || true; echo "${cron_job}") \
        | crontab -u "${cron_user}" -
    success "Added cron job for ${cron_user}: Sundays at 04:00"
}

case "$(uname -s)" in
    Darwin) setup_launchd ;;
    *)      setup_cron ;;
esac

# ── Done ──────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}✔  AdShield installation complete!${NC}\n"
echo ""
info "Useful commands:"
echo "    adshield status       Show current status"
echo "    adshield update       Update blocklists now"
echo "    adshield whitelist    Manage whitelisted domains"
echo "    adshield deactivate   Temporarily disable blocking"
echo ""
info "To uninstall:  sudo bash ${SCRIPT_DIR}/uninstall.sh"
echo ""
