# update-my-pi

**Systemupdate-Script für den Raspberry Pi (durin) — Debian 12 Bookworm, ARM64**

Einheitliches Update-Script für alle Paketmanager und Tools auf dem System. Inspiriert von [update-my-mac](https://github.com/olafgeibig/update-my-mac).

## Motivation

Verschiedene Paketquellen (apt, npm, uv, pip, Docker, Cargo) machen System-Updates zum Flickenteppich. Dieses Script fasst alles in einem Befehl zusammen — ähnlich wie `brew upgrade --all` auf dem Mac.

## Features

- **Ein Befehl** — alle Updates auf einmal
- **Modular** — einzelne Komponenten gezielt updaten
- **Ausführliches Logging** — nachvollziehbar was passiert ist
- **Graceful Degradation** — fehlende Tools werden übersprungen, kein Abbruch
- **Installierbar** — `--install` macht es global verfügbar

## Komponenten

| Modul | Befehl | Quellen |
|-------|--------|---------|
| **apt** | `sudo apt update && apt upgrade` | Debian-Paketverwaltung |
| **npm** | `npm update --location=global` | Globale Node-Pakete |
| **uv** | `uv self update` + `uv tool upgrade --all` | Python-Tools (UV) |
| **pip** | `pip3 install --upgrade --user` | Python-User-Pakete |
| **Docker** | `docker system prune` | Unbenutzte Container/Images |
| **Cargo** | `rustup update` | Rust-Toolchain (falls installiert) |

## Verwendung

```bash
# Quick-Update (Standard: apt, npm, uv, pip, Docker)
./update-my-pi.sh

# Full-Update (+ Cargo, Cache-Bereinigung)
./update-my-pi.sh --full

# Einzelne Module
./update-my-pi.sh --apt           # Nur apt
./update-my-pi.sh --npm           # Nur npm
./update-my-pi.sh --uv            # Nur uv
./update-my-pi.sh --pip           # Nur pip3
./update-my-pi.sh --docker        # Nur Docker Prune
./update-my-pi.sh --cargo         # Nur Cargo (rustup)
./update-my-pi.sh --cleanup       # Nur Caches leeren

# Installation (global verfügbar)
sudo ./update-my-pi.sh --install
# Danach: update-my-pi

# Hilfe
./update-my-pi.sh --help
```

## Installation

```bash
sudo ./update-my-pi.sh --install
```

Danach ist `update-my-pi` global verfügbar und kann von überall ausgeführt werden.

## Logging

- **Ort:** `~/.local/share/update-my-pi/`
- **Format:** `update-YYYYMMDD_HHMMSS.log`
- **Inhalt:** Zeitgestempelte Logs aller Befehle mit Exit-Codes

## Voraussetzungen

- **Debian 12 (Bookworm)** oder kompatibel
- **sudo** für apt-Update
- **optional:** rustup (`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`)

## Lizenz

Apache-2.0
