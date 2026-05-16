#!/bin/bash
#
# update-my-pi.sh — System update script for Raspberry Pi (durin)
#
# Runs updates across multiple package managers:
#   apt, npm, uv, Docker, Cargo (rustup), and manually extracted .deb packages.
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

# ─── Manually Installed Packages ───────────────────────────────────────────
# Each entry: "<name>|<binary_path>|<install_dir>|<github_repo>|<version_flag>"
# The script checks the latest GitHub release and updates if newer.
MANUAL_PACKAGES=(
  "code-server|$HOME/.local/lib/code-server/bin/code-server|$HOME/.local/lib/code-server|coder/code-server|--version"
)

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

semver_compare() {
  # Returns 0 if $1 < $2, 1 otherwise
  [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ] && [ "$1" != "$2" ]
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
  ./update-my-pi.sh --full             # Full mode (+ Cargo, manual packages, cleanup)
  ./update-my-pi.sh --quick            # Same as default

  Individual modules:
  ./update-my-pi.sh --apt              # apt only
  ./update-my-pi.sh --npm              # npm global packages only
  ./update-my-pi.sh --uv               # uv only
  ./update-my-pi.sh --docker           # Docker cleanup only
  ./update-my-pi.sh --cargo            # Cargo (rustup) only
  ./update-my-pi.sh --manual           # Manually installed packages (code-server)
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

update_manual_packages() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ Manual Packages ═══${NC}" | tee -a "$LOG_FILE"

  for entry in "${MANUAL_PACKAGES[@]}"; do
    IFS='|' read -r name binary install_dir repo version_flag <<< "$entry"

    echo -e "${BLUE}  → $name${NC}" | tee -a "$LOG_FILE"

    # Check if installed
    if [ ! -f "$binary" ]; then
      echo -e "${YELLOW}    ⚠ Not installed at $binary — skipping${NC}" | tee -a "$LOG_FILE"
      continue
    fi

    # Get current version
    local current_version
    current_version=$("$binary" "$version_flag" 2>/dev/null | head -n1 | awk '{print $1}')
    if [ -z "$current_version" ]; then
      echo -e "${YELLOW}    ⚠ Could not determine current version — skipping${NC}" | tee -a "$LOG_FILE"
      continue
    fi
    echo -e "    Current: $current_version" | tee -a "$LOG_FILE"

    # Fetch latest version from GitHub API
    local latest_version
    latest_version=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": "//;s/".*//' | sed 's/^v//')
    if [ -z "$latest_version" ]; then
      echo -e "${YELLOW}    ⚠ Could not fetch latest version from GitHub — skipping${NC}" | tee -a "$LOG_FILE"
      continue
    fi
    echo -e "    Latest:  $latest_version" | tee -a "$LOG_FILE"

    # Compare versions
    if ! semver_compare "$current_version" "$latest_version"; then
      echo -e "${GREEN}    ✓ Already up to date${NC}" | tee -a "$LOG_FILE"
      continue
    fi

    echo -e "    ${YELLOW}↻ Updating to $latest_version ...${NC}" | tee -a "$LOG_FILE"

    # Determine download URL (code-server follows a specific pattern)
    local download_url=""
    case "$name" in
      code-server)
        download_url="https://github.com/$repo/releases/download/v${latest_version}/code-server_${latest_version}_arm64.deb"
        ;;
      *)
        echo -e "${RED}    ✗ No download pattern defined for $name${NC}" | tee -a "$LOG_FILE"
        continue
        ;;
    esac

    # Download .deb to temp dir
    local tmp_dir
    tmp_dir=$(mktemp -d)
    local deb_file="$tmp_dir/${name}.deb"

    if ! curl -fsSL -o "$deb_file" "$download_url"; then
      echo -e "${RED}    ✗ Download failed${NC}" | tee -a "$LOG_FILE"
      rm -rf "$tmp_dir"
      continue
    fi

    # Extract .deb over the existing installation directory
    # Stop the service first if it's code-server
    if [ "$name" = "code-server" ] && systemctl --user is-active --quiet code-server 2>/dev/null; then
      echo -e "    Stopping code-server service ..." | tee -a "$LOG_FILE"
      systemctl --user stop code-server
    fi

    # Extract the new version over the install directory
    # .deb contents: ./usr/lib/code-server/ -> we extract to the parent of install_dir
    local extract_dir
    extract_dir=$(dirname "$install_dir")
    dpkg-deb -x "$deb_file" "$tmp_dir/extracted"
    # The .deb has files at usr/lib/code-server/... — copy them over
    if [ -d "$tmp_dir/extracted/usr/lib/code-server" ]; then
      rsync -a --delete "$tmp_dir/extracted/usr/lib/code-server/" "$install_dir/"
    elif [ -d "$tmp_dir/extracted/usr/share/code-server" ]; then
      rsync -a --delete "$tmp_dir/extracted/usr/share/code-server/" "$install_dir/"
    else
      echo -e "${YELLOW}    ⚠ Unexpected .deb structure — extracting directly${NC}" | tee -a "$LOG_FILE"
      cp -r "$tmp_dir/extracted"/* "$install_dir/"
    fi

    # Cleanup
    rm -rf "$tmp_dir"

    # Restart service
    if [ "$name" = "code-server" ] && systemctl --user --quiet is-enabled code-server 2>/dev/null; then
      systemctl --user start code-server
      echo -e "    Restarted code-server service" | tee -a "$LOG_FILE"
    fi

    echo -e "${GREEN}    ✓ $name updated to $latest_version${NC}" | tee -a "$LOG_FILE"
  done

  echo -e "${GREEN}✓ Manual packages update complete${NC}" | tee -a "$LOG_FILE"
}

do_cleanup() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ Cache Cleanup ═══${NC}" | tee -a "$LOG_FILE"

  if check_command npm; then
    log_command "npm cache clean --force 2>/dev/null || true" "npm: clean cache"
  fi

  if check_command uv; then
    log_command "uv cache prune 2>/dev/null || true" "uv: prune cache"
  fi

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
      update_manual_packages
      do_cleanup
      ;;
    --apt)        update_apt ;;
    --npm)        update_npm ;;
    --uv)         update_uv ;;
    --docker)     update_docker ;;
    --cargo)      update_cargo ;;
    --manual)     update_manual_packages ;;
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

  echo ""
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Update complete — Log: $LOG_FILE${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo ""
}

main "$@"
