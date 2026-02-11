#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -ne 1 ]; then
  echo "Usage: $0 <backup_name>" >&2
  echo "Tip: scripts/deploy.sh list-backups" >&2
  exit 1
fi

"$ROOT_DIR/scripts/deploy.sh" rollback "$1"
