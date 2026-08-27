#!/usr/bin/env bash
# Deploy heavyblue-nest static assets (public/) to the local nginx origin.
# Usage:
#   ./scripts/deploy-origin.sh              # pull current branch + rsync
#   ./scripts/deploy-origin.sh --no-pull    # rsync only
#   WEB_ROOT=/var/www/foo ./scripts/deploy-origin.sh
#   DEPLOY_BRANCH=main ./scripts/deploy-origin.sh
#
# Requires: git, rsync; sudo when not running as root.

set -euo pipefail

NO_PULL=0
for arg in "$@"; do
  case "$arg" in
    --no-pull|-n) NO_PULL=1 ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PUBLIC_DIR="${REPO_ROOT}/public"
WEB_ROOT="${WEB_ROOT:-/var/www/heavybluewoodpecker}"
BRANCH="${DEPLOY_BRANCH:-}"

log() { printf '[deploy] %s\n' "$*"; }
die() { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git not found"
command -v rsync >/dev/null || die "rsync not found"
[[ -d "$PUBLIC_DIR" ]] || die "missing public/ at $PUBLIC_DIR"
[[ -d "$REPO_ROOT/.git" ]] || die "not a git repo: $REPO_ROOT"

if [[ "$(id -u)" -eq 0 ]]; then
  NEED_SUDO=0
else
  NEED_SUDO=1
  command -v sudo >/dev/null || die "sudo is required to write $WEB_ROOT"
  log "using sudo for $WEB_ROOT"
fi

run_root() {
  if [[ "$NEED_SUDO" -eq 1 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

cd "$REPO_ROOT"

if [[ "$NO_PULL" -eq 0 ]]; then
  log "fetching origin..."
  git fetch --prune origin

  if [[ -z "$BRANCH" ]]; then
    BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  fi
  if [[ "$BRANCH" == "HEAD" ]]; then
    die "detached HEAD; set DEPLOY_BRANCH=main (or another branch)"
  fi

  log "checking out $BRANCH and pulling..."
  git checkout "$BRANCH"
  if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH}"; then
    git pull --ff-only origin "$BRANCH"
  else
    git pull --ff-only
  fi
else
  log "skipping git pull (--no-pull)"
fi

COMMIT="$(git rev-parse HEAD)"
SHORT="$(git rev-parse --short HEAD)"
REMOTE_URL="$(git config --get remote.origin.url || true)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
DEPLOYED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST_NAME="$(hostname -f 2>/dev/null || hostname)"

log "commit ${SHORT} (${COMMIT})"
log "syncing ${PUBLIC_DIR}/ -> ${WEB_ROOT}/"

run_root mkdir -p "$WEB_ROOT"
run_root rsync -a --delete \
  --exclude '.deployed-from' \
  --exclude '.git' \
  "${PUBLIC_DIR}/" "${WEB_ROOT}/"

# Provenance file (sudo tee so redirect is not needed as root)
{
  printf 'repo=%s\n' "$REMOTE_URL"
  printf 'path=public/\n'
  printf 'branch=%s\n' "$CURRENT_BRANCH"
  printf 'commit=%s\n' "$COMMIT"
  printf 'deployed_at=%s\n' "$DEPLOYED_AT"
  printf 'host=%s\n' "$HOST_NAME"
} | run_root tee "${WEB_ROOT}/.deployed-from" >/dev/null

if command -v nginx >/dev/null; then
  if run_root nginx -t; then
    if command -v systemctl >/dev/null && systemctl is-active --quiet nginx 2>/dev/null; then
      log "reloading nginx"
      run_root systemctl reload nginx
    fi
  else
    die "nginx -t failed after rsync"
  fi
fi

log "done"
log "provenance: ${WEB_ROOT}/.deployed-from"
if command -v curl >/dev/null; then
  if curl -sf -o /dev/null -H 'Host: heavybluewoodpecker.com' http://127.0.0.1/; then
    log "local origin check: OK"
  else
    log "local origin check: skipped/failed (nginx may still be fine via tunnel)"
  fi
fi
