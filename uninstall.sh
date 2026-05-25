#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
#  CliShield Uninstaller — macOS / Linux
#  Cleanly removes CliShield and restores system state.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${BLUE}[INFO]${NC}  %s\n" "$*"; }
success() { printf "${GREEN}[  OK]${NC}  %s\n" "$*"; }
warn()    { printf "${YELLOW}[WARN]${NC}  %s\n" "$*"; }
fail()    { printf "${RED}[FAIL]${NC}  %s\n" "$*"; exit 1; }

# ── Configuration ─────────────────────────────────────────────
INSTALL_BIN="/usr/local/bin/clishield"
LAUNCHD_LABEL="com.clishield.update"

REAL_HOME="${SUDO_USER:+$(eval echo "~${SUDO_USER}")}"
REAL_HOME="${REAL_HOME:-$HOME}"
CONFIG_DIR="${REAL_HOME}/.clishield"
LAUNCHD_PLIST="${REAL_HOME}/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

# ── Banner ────────────────────────────────────────────────────
printf "${CYAN}${BOLD}"
cat << 'EOF'

    ╔══════════════════════════════════════╗
    ║     CliShield — Uninstaller          ║
    ╚══════════════════════════════════════╝

EOF
printf "${NC}"

# ── Check for root ────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    fail "This uninstaller must be run as root.  Try:  sudo bash uninstall.sh"
fi

# ── 1. Deactivate ad blocking ────────────────────────────────
info "Deactivating CliShield…"
if [[ -x "${INSTALL_BIN}" ]]; then
    if "${INSTALL_BIN}" deactivate 2>/dev/null; then
        success "CliShield deactivated — original hosts file restored."
    else
        warn "Deactivation returned a non-zero exit code. Your hosts file may need manual review."
    fi
else
    warn "clishield binary not found at ${INSTALL_BIN}; skipping deactivation."
fi

# ── 2. Remove the binary ─────────────────────────────────────
info "Removing ${INSTALL_BIN}…"
if [[ -f "${INSTALL_BIN}" ]]; then
    rm -f "${INSTALL_BIN}"
    success "Removed ${INSTALL_BIN}"
else
    warn "${INSTALL_BIN} does not exist; nothing to remove."
fi

# ── 3. Remove launchd job (macOS) ─────────────────────────────
if [[ "$(uname -s)" == "Darwin" ]]; then
    info "Removing launchd job…"
    if [[ -f "${LAUNCHD_PLIST}" ]]; then
        launchctl unload "${LAUNCHD_PLIST}" 2>/dev/null || true
        rm -f "${LAUNCHD_PLIST}"
        success "Removed launchd plist: ${LAUNCHD_PLIST}"
    else
        warn "No launchd plist found at ${LAUNCHD_PLIST}; skipping."
    fi
else
    # ── 3b. Remove cron job (Linux) ───────────────────────────
    info "Removing cron job…"
    CRON_USER="${SUDO_USER:-root}"
    if crontab -u "${CRON_USER}" -l 2>/dev/null | grep -q "${INSTALL_BIN}"; then
        crontab -u "${CRON_USER}" -l 2>/dev/null \
            | grep -v "${INSTALL_BIN}" \
            | crontab -u "${CRON_USER}" -
        success "Removed cron entry for ${CRON_USER}."
    else
        warn "No clishield cron entry found for ${CRON_USER}; skipping."
    fi
fi

# ── 4. Remove config directory ────────────────────────────────
info "Removing config directory ${CONFIG_DIR}…"
if [[ -d "${CONFIG_DIR}" ]]; then
    rm -rf "${CONFIG_DIR}"
    success "Removed ${CONFIG_DIR}"
else
    warn "${CONFIG_DIR} does not exist; nothing to remove."
fi

# ── Done ──────────────────────────────────────────────────────
echo ""
printf "${GREEN}${BOLD}✔  CliShield has been completely uninstalled.${NC}\n"
echo ""
info "Your system's hosts file has been restored to its original state."
info "Thank you for using CliShield!"
echo ""
