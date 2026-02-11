#!/usr/bin/env bash
set -euo pipefail

# Sync already-deployed static files from nerd primary node to optional secondary nodes.
#
# Target format:
#   user@host:/absolute/path
#
# Targets can be provided by either:
#   1) SYNC_TARGETS env (comma/newline/space separated), or
#   2) SYNC_TARGETS_FILE (default: scripts/sync-targets.conf), one target per line.
#
# Example:
#   SYNC_ENABLED=true SYNC_TARGETS="mars@dc6:/data/nginx/wwwroot/www.tingxueren.com" ./scripts/sync-nodes.sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_DIR="${SOURCE_DIR:-${TARGET_DIR:-${HOME}/data/nginx/wwwroot/www.tingxueren.com}}"
SYNC_ENABLED="${SYNC_ENABLED:-false}"
SYNC_TARGETS="${SYNC_TARGETS:-}"
SYNC_TARGETS_FILE="${SYNC_TARGETS_FILE:-$ROOT_DIR/scripts/sync-targets.conf}"
SYNC_SSH_OPTS="${SYNC_SSH_OPTS:-}"
RSYNC_OPTS="${RSYNC_OPTS:--az --delete}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
  cat <<EOF
Usage:
  $0 [--dry-run]

Env:
  SYNC_ENABLED      Enable sync when true/1/yes/on (default: false)
  SOURCE_DIR        Source directory on nerd (default: TARGET_DIR or nginx static dir)
  SYNC_TARGETS      Target list: user@host:/path (comma/newline/space separated)
  SYNC_TARGETS_FILE Config file fallback (default: scripts/sync-targets.conf)
  SYNC_SSH_OPTS     Extra ssh options, e.g. "-i ~/.ssh/id_rsa -p 22"
  RSYNC_OPTS        Override rsync options (default: -az --delete)
  DRY_RUN           1 to enable dry-run (same as --dry-run)

Config file format (one target per line):
  # comments allowed
  mars@dc6:/data/nginx/wwwroot/www.tingxueren.com
EOF
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[sync] Missing required command: $1" >&2
    exit 1
  }
}

normalize_targets() {
  if [ -n "$SYNC_TARGETS" ]; then
    printf '%s\n' "$SYNC_TARGETS" | tr ', ' '\n\n' | sed '/^$/d'
    return
  fi

  if [ -f "$SYNC_TARGETS_FILE" ]; then
    sed 's/#.*$//' "$SYNC_TARGETS_FILE" | sed 's/^\s*//; s/\s*$//' | sed '/^$/d'
    return
  fi
}

main() {
  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    return 0
  fi

  if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=1
  fi

  if ! is_true "$SYNC_ENABLED"; then
    echo "[sync] SYNC_ENABLED=$SYNC_ENABLED, skip node sync."
    return 0
  fi

  require_cmd rsync
  require_cmd ssh

  if [ ! -d "$SOURCE_DIR" ]; then
    echo "[sync] Source dir does not exist: $SOURCE_DIR" >&2
    exit 1
  fi

  mapfile -t targets < <(normalize_targets)
  if [ "${#targets[@]}" -eq 0 ]; then
    echo "[sync] Enabled but no targets found. Configure SYNC_TARGETS or $SYNC_TARGETS_FILE" >&2
    exit 1
  fi

  local -a failed=()
  local rsync_cmd=(rsync)
  local -a rsync_opts_arr

  # shellcheck disable=SC2206
  rsync_opts_arr=($RSYNC_OPTS)
  rsync_cmd+=("${rsync_opts_arr[@]}")

  if [ -n "$SYNC_SSH_OPTS" ]; then
    rsync_cmd+=(-e "ssh $SYNC_SSH_OPTS")
  fi

  if [ "$DRY_RUN" = "1" ]; then
    rsync_cmd+=(--dry-run)
    echo "[sync] DRY RUN mode enabled"
  fi

  echo "[sync] Source: $SOURCE_DIR"
  echo "[sync] Targets: ${#targets[@]}"

  for target in "${targets[@]}"; do
    echo "[sync] -> syncing to $target"
    if "${rsync_cmd[@]}" "$SOURCE_DIR/" "$target/"; then
      echo "[sync] ✅ success: $target"
    else
      echo "[sync] ❌ failed: $target"
      failed+=("$target")
    fi
  done

  if [ "${#failed[@]}" -gt 0 ]; then
    echo "[sync] Completed with failures (${#failed[@]} target(s)):" >&2
    printf '  - %s\n' "${failed[@]}" >&2
    exit 2
  fi

  echo "[sync] All targets synced successfully."
}

main "$@"
