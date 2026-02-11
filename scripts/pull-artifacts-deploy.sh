#!/usr/bin/env bash
set -euo pipefail

# Pull static artifact branch and deploy to nginx target dir.
# Default artifact branch: site-artifacts

REPO_URL="${REPO_URL:-git@github.com:tingxueren/tingxueren.github.io.git}"
ARTIFACT_BRANCH="${ARTIFACT_BRANCH:-site-artifacts}"
WORKTREE_DIR="${WORKTREE_DIR:-${HOME}/data/nginx/artifacts/tingxueren-site-artifacts}"
TARGET_DIR="${TARGET_DIR:-${HOME}/data/nginx/wwwroot/www.tingxueren.com}"
BACKUP_BASE="${BACKUP_BASE:-${HOME}/data/nginx/wwwroot/.deploy_backups}"
KEEP_BACKUPS="${KEEP_BACKUPS:-10}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$BACKUP_BASE/$TS"
STAMP_FILE="$WORKTREE_DIR/.last_deployed_commit"
NOTIFY_ENABLED="${NOTIFY_ENABLED:-true}"
NOTIFY_CHANNEL="${NOTIFY_CHANNEL:-telegram}"
NOTIFY_TARGET="${NOTIFY_TARGET:-426648490}"
SITE_URL="${SITE_URL:-https://nerd.tingxueren.com}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*"
}

send_notify() {
  [ "$NOTIFY_ENABLED" = "true" ] || return 0
  command -v openclaw >/dev/null 2>&1 || return 0
  local text="$1"
  openclaw message send --channel "$NOTIFY_CHANNEL" --target "$NOTIFY_TARGET" --message "$text" >/dev/null 2>&1 || true
}

on_error() {
  local code=$?
  send_notify "[博客发布失败] artifact 同步失败（exit=$code）。请检查 nerd 上 systemd 日志：tingxueren-artifact-sync.service"
  exit "$code"
}

trap on_error ERR

ensure_worktree() {
  mkdir -p "$(dirname "$WORKTREE_DIR")"

  if [ ! -d "$WORKTREE_DIR/.git" ]; then
    log "Init artifact worktree: $WORKTREE_DIR ($ARTIFACT_BRANCH)"
    git clone --depth=1 --branch "$ARTIFACT_BRANCH" "$REPO_URL" "$WORKTREE_DIR"
    return
  fi

  git -C "$WORKTREE_DIR" remote set-url origin "$REPO_URL"
  git -C "$WORKTREE_DIR" fetch --depth=1 origin "$ARTIFACT_BRANCH"
  git -C "$WORKTREE_DIR" checkout -q "$ARTIFACT_BRANCH"
  git -C "$WORKTREE_DIR" reset --hard "origin/$ARTIFACT_BRANCH" >/dev/null
}

backup_target() {
  mkdir -p "$BACKUP_BASE"
  if [ -d "$TARGET_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    rsync -a --delete "$TARGET_DIR/" "$BACKUP_DIR/"
    log "Backup created: $BACKUP_DIR"

    # keep latest N backups
    local old_backups
    old_backups="$(find "$BACKUP_BASE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | head -n -"$KEEP_BACKUPS" || true)"
    if [ -n "$old_backups" ]; then
      while IFS= read -r name; do
        [ -n "$name" ] || continue
        rm -rf "$BACKUP_BASE/$name"
      done <<< "$old_backups"
    fi
  fi
}

deploy_artifacts() {
  local head
  head="$(git -C "$WORKTREE_DIR" rev-parse --short=12 HEAD)"
  local last=""

  if [ -f "$STAMP_FILE" ]; then
    last="$(cat "$STAMP_FILE" 2>/dev/null || true)"
  fi

  if [ "$head" = "$last" ]; then
    log "No new artifact commit ($head), skip deploy"
    return 0
  fi

  backup_target
  mkdir -p "$TARGET_DIR"
  rsync -a --delete \
    --exclude='.git' \
    --exclude='.github' \
    "$WORKTREE_DIR/" "$TARGET_DIR/"

  echo "$head" > "$STAMP_FILE"
  log "Deploy done -> $TARGET_DIR (commit: $head)"
  send_notify "[博客已更新] artifact commit: $head 已发布到 nerd。站点：$SITE_URL"
}

main() {
  require_cmd git
  require_cmd rsync

  ensure_worktree
  deploy_artifacts
}

main "$@"
