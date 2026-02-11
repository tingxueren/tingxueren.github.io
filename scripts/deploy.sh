#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
TARGET_DIR="${HOME}/data/nginx/wwwroot/www.tingxueren.com"
BACKUP_BASE="${HOME}/data/nginx/wwwroot/.deploy_backups"
CURRENT_LINK="$BACKUP_BASE/current"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/$TS"

usage() {
  echo "Usage: $0 [deploy|rollback <backup_name>|list-backups]"
}

do_build() {
  cd "$ROOT_DIR"
  npm run build
}

do_deploy() {
  mkdir -p "$BACKUP_BASE"
  if [ -d "$TARGET_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    rsync -a --delete "$TARGET_DIR/" "$BACKUP_DIR/"
    ln -sfn "$BACKUP_DIR" "$CURRENT_LINK"
    echo "Backup created: $BACKUP_DIR"
  fi

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
  rsync -a --delete "$src/" "$TARGET_DIR/"
  echo "Rollback done <- $src"
}

cmd="${1:-deploy}"
case "$cmd" in
  deploy)
    do_build
    do_deploy
    ;;
  rollback)
    [ $# -eq 2 ] || { usage; exit 1; }
    rollback "$2"
    ;;
  list-backups)
    ls -1 "$BACKUP_BASE" || true
    ;;
  *)
    usage
    exit 1
    ;;
esac
