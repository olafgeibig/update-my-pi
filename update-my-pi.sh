#!/bin/bash
#
# update-my-pi.sh — System update script for Raspberry Pi (durin)
#
# Runs updates across multiple package managers:
#   apt, npm, uv, Docker, Cargo (rustup), and more.
#
# Author:   Olaf Geibig
# Version:  v2026.05.16
# License:  Apache-2.0

set -euo pipefail

# ─── Version & Configuration ───────────────────────────────────────────────
VERSION="v2026.05.16"
LOG_DIR="$HOME/.local/share/update-my-pi"
LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d_%H%M%S).log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ─── Helpers ────────────────────────────────────────────────────────────────

log_command() {
  local cmd="$1"
  local label="$2"
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ $label ═══${NC}" | tee -a "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] $cmd" >> "$LOG_FILE"

  eval "$cmd" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OUT] $line" >> "$LOG_FILE"
    echo "$line"
  done

  local exit_code=${PIPESTATUS[0]}
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [EXIT] $exit_code" >> "$LOG_FILE"

  if [ "$exit_code" -eq 0 ]; then
    echo -e "${GREEN}✓ $label succeeded${NC}" | tee -a "$LOG_FILE"
  else
    echo -e "${RED}✗ $label failed (exit: $exit_code)${NC}" | tee -a "$LOG_FILE"
  fi
  echo "" | tee -a "$LOG_FILE"
  return "$exit_code"
}

check_command() {
  command -v "$1" >/dev/null 2>&1
}

header() {
  echo ""
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  update-my-pi $VERSION — $(date '+%Y-%m-%d %H:%M:%S')${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo ""
}

usage() {
  cat <<EOF
update-my-pi $VERSION

Usage:
  ./update-my-pi.sh                    # Quick mode (apt, npm, uv, Docker)
  ./update-my-pi.sh --full             # Full mode (+ Cargo, Cleanup)
  ./update-my-pi.sh --quick            # Same as default

  Individual modules:
  ./update-my-pi.sh --apt              # apt only
  ./update-my-pi.sh --npm              # npm global packages only
  ./update-my-pi.sh --uv               # uv only
  ./update-my-pi.sh --docker           # Docker cleanup only
  ./update-my-pi.sh --cargo            # Cargo (rustup) only
  ./update-my-pi.sh --cleanup          # Cache cleanup only
  ./update-my-pi.sh --help             # This help

Installation:
  sudo ./update-my-pi.sh --install     # Install to /usr/local/bin
  ./update-my-pi.sh --uninstall        # Remove
EOF
  exit 0
}

# ─── Update Modules ─────────────────────────────────────────────────────────

update_apt() {
  if ! check_command apt-get; then
    echo -e "${YELLOW}⚠ apt-get not found — skipping${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "sudo apt-get update" "apt: update package lists"
  log_command "sudo apt-get upgrade --yes" "apt: upgrade packages"
  log_command "sudo apt-get autoremove --yes" "apt: remove unused dependencies"
  log_command "sudo apt-get autoclean" "apt: clean package cache"
}

update_npm() {
  if ! check_command npm; then
    echo -e "${YELLOW}⚠ npm not found — skipping${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "npm update --location=global" "npm: update global packages"
}

update_uv() {
  if ! check_command uv; then
    echo -e "${YELLOW}⚠ uv not found — skipping${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "uv self update" "uv: update itself"
  log_command "uv tool upgrade --all" "uv: upgrade tools"
}

update_cargo() {
  if ! check_command rustup; then
    echo -e "${YELLOW}⚠ rustup not found — skipping${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "rustup update" "rustup: update Rust toolchain"

  if check_command cargo; then
    # cargo-update enables 'cargo install-update -a'
    if cargo install --list 2>/dev/null | grep -q "cargo-update"; then
      log_command "cargo install-update --all" "cargo: update installed crates"
    else
      echo -e "${YELLOW}⚠ cargo-update not installed — run 'cargo install cargo-update' for crate updates${NC}" | tee -a "$LOG_FILE"
    fi
  fi
}

update_docker() {
  if ! check_command docker; then
    echo -e "${YELLOW}⚠ docker not found — skipping${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "docker system prune --force --all --volumes 2>/dev/null || docker system prune --force" "docker: remove unused resources"
}

do_cleanup() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ Cache Cleanup ═══${NC}" | tee -a "$LOG_FILE"

  # npm cache
  if check_command npm; then
    log_command "npm cache clean --force 2>/dev/null || true" "npm: clean cache"
  fi

  # uv cache
  if check_command uv; then
    log_command "uv cache prune 2>/dev/null || true" "uv: prune cache"
  fi

  # ~/.cache cleanup
  log_command "rm -rf \"$HOME\"/.cache/opencode/node_modules 2>/dev/null || true" "cache: remove opencode node_modules"

  echo -e "${GREEN}✓ Cache cleanup complete${NC}" | tee -a "$LOG_FILE"
}

# ─── Install / Uninstall ──────────────────────────────────────────────────

do_install() {
  local target="/usr/local/bin/update-my-pi"
  echo -e "${BLUE}Installing update-my-pi to $target ...${NC}"
  sudo cp "$0" "$target"
  sudo chmod +x "$target"
  echo -e "${GREEN}✓ Installed as $target${NC}"
  echo "  Run 'update-my-pi' from anywhere."
}

do_uninstall() {
  local target="/usr/local/bin/update-my-pi"
  if [ -f "$target" ]; then
    sudo rm "$target"
    echo -e "${GREEN}✓ Removed $target${NC}"
  else
    echo -e "${YELLOW}⚠ update-my-pi is not installed${NC}"
  fi
}

# ─── Main Logic ────────────────────────────────────────────────────────────

main() {
  mkdir -p "$LOG_DIR"
  header

  MODE="${1:-quick}"

  case "$MODE" in
    --quick|quick|"")
      update_apt
      update_npm
      update_uv
      update_docker
      ;;
    --full|full|--all|all)
      update_apt
      update_npm
      update_uv
      update_docker
      update_cargo
      do_cleanup
      ;;
    --apt)        update_apt ;;
    --npm)        update_npm ;;
    --uv)         update_uv ;;
    --docker)     update_docker ;;
    --cargo)      update_cargo ;;
    --cleanup)    do_cleanup ;;
    --install)    do_install ; exit 0 ;;
    --uninstall)  do_uninstall ; exit 0 ;;
    --help|-h)    usage ;;
    *)
      echo -e "${RED}Unknown option: $MODE${NC}"
      echo "Use --help for available options."
      exit 1
      ;;
  esac

  # Summary
  echo ""
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Update complete — Log: $LOG_FILE${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo ""
}

main "$@"
