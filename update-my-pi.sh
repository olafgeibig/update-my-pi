#!/bin/bash
#
# update-my-pi.sh — Systemupdate für den Raspberry Pi (durin)
#
# Führt Updates über verschiedene Paketmanager aus:
#   apt, npm, uv, pip, Docker, Cargo (rustup), und mehr.
#
# Autor:   Olaf Geibig
# Version: v2026.05.16
# Lizenz:  Apache-2.0

set -euo pipefail

# ─── Version & Konfiguration ───────────────────────────────────────────────
VERSION="v2026.05.16"
LOG_DIR="$HOME/.local/share/update-my-pi"
LOG_FILE="$LOG_DIR/update-$(date +%Y%m%d_%H%M%S).log"

# Farben
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

log_command() {
  local cmd="$1"
  local label="$2"
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ $label ═══${NC}" | tee -a "$LOG_FILE"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [CMD] $cmd" >> "$LOG_FILE"

  # Command ausführen, Output in Log + Terminal
  eval "$cmd" 2>&1 | while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OUT] $line" >> "$LOG_FILE"
    echo "$line"
  done

  local exit_code=${PIPESTATUS[0]}
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] [EXIT] $exit_code" >> "$LOG_FILE"

  if [ "$exit_code" -eq 0 ]; then
    echo -e "${GREEN}✓ $label erfolgreich${NC}" | tee -a "$LOG_FILE"
  else
    echo -e "${RED}✗ $label fehlgeschlagen (exit: $exit_code)${NC}" | tee -a "$LOG_FILE"
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

Verwendung:
  ./update-my-pi.sh                    # Quick-Modus (apt, npm, uv, pip, Docker)
  ./update-my-pi.sh --full             # Full-Modus (+ Cargo, Cleanup)
  ./update-my-pi.sh --quick            # Gleicher default

  Einzelne Module:
  ./update-my-pi.sh --apt              # Nur apt
  ./update-my-pi.sh --npm              # Nur npm globale Pakete
  ./update-my-pi.sh --uv               # Nur uv
  ./update-my-pi.sh --pip              # Nur pip3
  ./update-my-pi.sh --docker           # Nur Docker Cleanup
  ./update-my-pi.sh --cargo            # Nur Cargo (rustup)
  ./update-my-pi.sh --cleanup          # Nur Cache-Bereinigung
  ./update-my-pi.sh --help             # Diese Hilfe

Installation:
  sudo ./update-my-pi.sh --install     # Nach /usr/local/bin installieren
  ./update-my-pi.sh --uninstall        # Entfernen
EOF
  exit 0
}

# ─── Update-Module ─────────────────────────────────────────────────────────

update_apt() {
  if ! check_command apt-get; then
    echo -e "${YELLOW}⚠ apt-get nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "sudo apt-get update" "apt: Paketlisten aktualisieren"
  log_command "sudo apt-get upgrade --yes" "apt: Pakete upgraden"
  log_command "sudo apt-get autoremove --yes" "apt: nicht mehr benötigte Pakete entfernen"
  log_command "sudo apt-get autoclean" "apt: Cache bereinigen"
}

update_npm() {
  if ! check_command npm; then
    echo -e "${YELLOW}⚠ npm nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "npm update --location=global" "npm: globale Pakete aktualisieren"
}

update_uv() {
  if ! check_command uv; then
    echo -e "${YELLOW}⚠ uv nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "uv self update" "uv: selbst aktualisieren"
  log_command "uv tool upgrade --all" "uv: Tools aktualisieren"
}

update_pip() {
  if ! check_command pip3; then
    echo -e "${YELLOW}⚠ pip3 nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "pip3 install --upgrade --user pip" "pip3: pip selbst aktualisieren"

  # Optional: Alle User-Pakete upgraden
  local outdated
  outdated=$(pip3 list --outdated --user --format=columns 2>/dev/null | tail -n +3 | awk '{print $1}')
  if [ -n "$outdated" ]; then
    log_command "pip3 install --upgrade --user $outdated" "pip3: User-Pakete upgraden"
  else
    echo -e "${GREEN}pip3: alle User-Pakete aktuell${NC}" | tee -a "$LOG_FILE"
  fi
}

update_cargo() {
  if ! check_command rustup; then
    echo -e "${YELLOW}⚠ rustup nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "rustup update" "rustup: Rust-Toolchain aktualisieren"

  if check_command cargo; then
    # cargo-update ermöglicht 'cargo install-update -a'
    if cargo install --list 2>/dev/null | grep -q "cargo-update"; then
      log_command "cargo install-update --all" "cargo: installierte Crates aktualisieren"
    else
      echo -e "${YELLOW}⚠ cargo-update nicht installiert — 'cargo install cargo-update' für Crate-Updates${NC}" | tee -a "$LOG_FILE"
    fi
  fi
}

update_docker() {
  if ! check_command docker; then
    echo -e "${YELLOW}⚠ docker nicht gefunden — überspringe${NC}" | tee -a "$LOG_FILE"
    return
  fi

  log_command "docker system prune --force --all --volumes 2>/dev/null || docker system prune --force" "docker: ungenutzte Ressourcen entfernen"
}

do_cleanup() {
  echo "" | tee -a "$LOG_FILE"
  echo -e "${BLUE}═══ Cache-Bereinigung ═══${NC}" | tee -a "$LOG_FILE"

  # npm Cache
  if check_command npm; then
    log_command "npm cache clean --force 2>/dev/null || true" "npm: Cache leeren"
  fi

  # uv Cache
  if check_command uv; then
    log_command "uv cache prune 2>/dev/null || true" "uv: Cache prunen"
  fi

  # pip Cache
  if check_command pip3; then
    log_command "pip3 cache purge 2>/dev/null || true" "pip3: Cache leeren"
  fi

  # ~/.cache aufräumen (nur offensichtliche Caches)
  log_command "rm -rf \"$HOME\"/.cache/opencode/node_modules 2>/dev/null || true" "Cache: opencode node_modules entfernen"

  echo -e "${GREEN}✓ Cache-Bereinigung abgeschlossen${NC}" | tee -a "$LOG_FILE"
}

# ─── Install / Uninstall ──────────────────────────────────────────────────

do_install() {
  local target="/usr/local/bin/update-my-pi"
  echo -e "${BLUE}Installiere update-my-pi nach $target ...${NC}"
  sudo cp "$0" "$target"
  sudo chmod +x "$target"
  echo -e "${GREEN}✓ Installiert als $target${NC}"
  echo "  Ab sofort einfach 'update-my-pi' ausführen."
}

do_uninstall() {
  local target="/usr/local/bin/update-my-pi"
  if [ -f "$target" ]; then
    sudo rm "$target"
    echo -e "${GREEN}✓ $target entfernt${NC}"
  else
    echo -e "${YELLOW}⚠ update-my-pi ist nicht installiert${NC}"
  fi
}

# ─── Hauptlogik ────────────────────────────────────────────────────────────

main() {
  mkdir -p "$LOG_DIR"
  header

  MODE="${1:-quick}"

  case "$MODE" in
    --quick|quick|"")
      update_apt
      update_npm
      update_uv
      update_pip
      update_docker
      ;;
    --full|full|--all|all)
      update_apt
      update_npm
      update_uv
      update_pip
      update_docker
      update_cargo
      do_cleanup
      ;;
    --apt)        update_apt ;;
    --npm)        update_npm ;;
    --uv)         update_uv ;;
    --pip)        update_pip ;;
    --docker)     update_docker ;;
    --cargo)      update_cargo ;;
    --cleanup)    do_cleanup ;;
    --install)    do_install ; exit 0 ;;
    --uninstall)  do_uninstall ; exit 0 ;;
    --help|-h)    usage ;;
    *)
      echo -e "${RED}Unbekannte Option: $MODE${NC}"
      echo "Verwende --help für verfügbare Optionen."
      exit 1
      ;;
  esac

  # Zusammenfassung
  echo ""
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  ✓ Update abgeschlossen — Log: $LOG_FILE${NC}"
  echo -e "${BLUE}══════════════════════════════════════════════════════════════${NC}"
  echo ""
}

main "$@"
