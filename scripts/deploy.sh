#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TARGET_DIR="${TARGET_DIR:-${HOME}/data/nginx/wwwroot/www.tingxueren.com}"
BACKUP_BASE="${BACKUP_BASE:-${HOME}/data/nginx/wwwroot/.deploy_backups}"
CURRENT_LINK="$BACKUP_BASE/current"
KEEP_BACKUPS="${KEEP_BACKUPS:-10}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/$TS"

usage() {
  cat <<EOF
Usage:
  $0 deploy           # build + backup + deploy
  $0 backup           # backup current target only
  $0 release          # deploy existing dist only
  $0 list-backups     # list available backups
  $0 rollback <name>  # rollback to named backup

Env overrides:
  TARGET_DIR, BACKUP_BASE, KEEP_BACKUPS
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

do_build() {
  cd "$ROOT_DIR"
  npm ci
  npm run build
}

do_backup() {
  mkdir -p "$BACKUP_BASE"
  if [ -d "$TARGET_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    rsync -a --delete "$TARGET_DIR/" "$BACKUP_DIR/"
    ln -sfn "$BACKUP_DIR" "$CURRENT_LINK"
    echo "Backup created: $BACKUP_DIR"

    # keep last N backups
    local old_backups
    old_backups="$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | head -n -"$KEEP_BACKUPS" || true)"
    if [ -n "$old_backups" ]; then
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        rm -rf "$BACKUP_BASE/$name"
      done <<< "$old_backups"
    fi
  else
    echo "Target dir not found, skip backup: $TARGET_DIR"
  fi
}

do_release() {
  [ -d "$DIST_DIR" ] || {
    echo "dist not found: $DIST_DIR" >&2
    exit 1
  }
  mkdir -p "$TARGET_DIR"
  rsync -a --delete "$DIST_DIR/" "$TARGET_DIR/"
  echo "Deploy done -> $TARGET_DIR"
}

rollback() {
  local name="$1"
  local src="$BACKUP_BASE/$name"
  if [ ! -d "$src" ]; then
    echo "Backup not found: $src" >&2
    exit 1
  fi
  mkdir -p "$TARGET_DIR"
  rsync -a --delete "$src/" "$TARGET_DIR/"
  ln -sfn "$src" "$CURRENT_LINK"
  echo "Rollback done <- $src"
}

cmd="${1:-deploy}"

require_cmd rsync
require_cmd npm

case "$cmd" in
  deploy)
    do_build
    do_backup
    do_release
    ;;
  backup)
    do_backup
    ;;
  release)
    do_release
    ;;
  rollback)
    [ $# -eq 2 ] || { usage; exit 1; }
    rollback "$2"
    ;;
  list-backups)
    ls -1 "$BACKUP_BASE" 2>/dev/null || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
