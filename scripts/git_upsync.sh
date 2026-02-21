#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Fork + upstream sync helper

Usage:
  scripts/git_upsync.sh [options]

Options:
  --upstream-url <url>    Add missing upstream remote with this URL
  --origin-url <url>      Set/add origin URL (your fork URL)
  --remote <name>         Upstream remote name (default: upstream)
  --origin-remote <name>  Fork remote name (default: origin)
  --base-branch <name>    Upstream base branch (default: main)
  --branch <name>         Local branch to sync (default: current branch)
  --no-origin-check       Skip origin reachability check
  -h, --help             Show help

Examples:
  scripts/git_upsync.sh
  scripts/git_upsync.sh --origin-url git@github.com:your-name/zeroclaw.git
  scripts/git_upsync.sh --upstream-url git@github.com:zeroclaw-labs/zeroclaw.git
  scripts/git_upsync.sh --remote upstream --base-branch main
USAGE
}

info() {
  echo "==> $*"
}

warn() {
  echo "warning: $*" >&2
}

error() {
  echo "error: $*" >&2
}

REMOTE_NAME="upstream"
ORIGIN_REMOTE="origin"
BASE_BRANCH="main"
WORK_BRANCH=""
UPSTREAM_URL=""
ORIGIN_URL=""
NO_ORIGIN_CHECK="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream-url)
      UPSTREAM_URL="${2:-}"
      [[ -n "$UPSTREAM_URL" ]] || {
        error "--upstream-url requires a value"
        exit 1
      }
      shift 2
      ;;
    --origin-url)
      ORIGIN_URL="${2:-}"
      [[ -n "$ORIGIN_URL" ]] || {
        error "--origin-url requires a value"
        exit 1
      }
      shift 2
      ;;
    --remote)
      REMOTE_NAME="${2:-}"
      [[ -n "$REMOTE_NAME" ]] || {
        error "--remote requires a value"
        exit 1
      }
      shift 2
      ;;
    --origin-remote)
      ORIGIN_REMOTE="${2:-}"
      [[ -n "$ORIGIN_REMOTE" ]] || {
        error "--origin-remote requires a value"
        exit 1
      }
      shift 2
      ;;
    --base-branch)
      BASE_BRANCH="${2:-}"
      [[ -n "$BASE_BRANCH" ]] || {
        error "--base-branch requires a value"
        exit 1
      }
      shift 2
      ;;
    --branch)
      WORK_BRANCH="${2:-}"
      [[ -n "$WORK_BRANCH" ]] || {
        error "--branch requires a value"
        exit 1
      }
      shift 2
      ;;
    --no-origin-check)
      NO_ORIGIN_CHECK="1"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "unknown option: $1"
      echo
      usage
      exit 1
      ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  error "not inside a git repository"
  exit 1
fi

CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD || true)"
if [[ -z "$CURRENT_BRANCH" ]]; then
  error "detached HEAD: switch to a branch or pass --branch <name> after checkout"
  exit 1
fi

if [[ -z "$WORK_BRANCH" ]]; then
  WORK_BRANCH="$CURRENT_BRANCH"
fi

if [[ "$WORK_BRANCH" != "$CURRENT_BRANCH" ]]; then
  error "current branch is '$CURRENT_BRANCH' but --branch is '$WORK_BRANCH'"
  echo "hint: switch first: git switch $WORK_BRANCH"
  exit 1
fi

if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
  if [[ -z "$UPSTREAM_URL" ]]; then
    error "remote '$REMOTE_NAME' does not exist"
    echo "hint: run with --upstream-url <url> to add it automatically"
    exit 1
  fi
  info "Adding remote '$REMOTE_NAME' -> $UPSTREAM_URL"
  git remote add "$REMOTE_NAME" "$UPSTREAM_URL"
fi

if [[ -n "$ORIGIN_URL" ]]; then
  if git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1; then
    info "Setting remote '$ORIGIN_REMOTE' URL -> $ORIGIN_URL"
    git remote set-url "$ORIGIN_REMOTE" "$ORIGIN_URL"
  else
    info "Adding remote '$ORIGIN_REMOTE' -> $ORIGIN_URL"
    git remote add "$ORIGIN_REMOTE" "$ORIGIN_URL"
  fi
fi

if [[ "$NO_ORIGIN_CHECK" == "0" ]]; then
  if git remote get-url "$ORIGIN_REMOTE" >/dev/null 2>&1; then
    if ! git ls-remote --exit-code "$ORIGIN_REMOTE" HEAD >/dev/null 2>&1; then
      warn "remote '$ORIGIN_REMOTE' is unreachable"
      warn "fix it with: git remote set-url $ORIGIN_REMOTE <your-fork-url>"
    fi
  else
    warn "remote '$ORIGIN_REMOTE' does not exist"
    warn "set it with: git remote add $ORIGIN_REMOTE <your-fork-url>"
  fi
fi

info "Fetching '$REMOTE_NAME' (pruned)"
git fetch --prune "$REMOTE_NAME"

REBASE_TARGET="$REMOTE_NAME/$BASE_BRANCH"
if ! git show-ref --verify --quiet "refs/remotes/$REBASE_TARGET"; then
  REMOTE_HEAD="$(git symbolic-ref -q --short "refs/remotes/$REMOTE_NAME/HEAD" || true)"
  if [[ -n "$REMOTE_HEAD" ]]; then
    warn "branch '$REBASE_TARGET' not found; fallback to '$REMOTE_HEAD'"
    REBASE_TARGET="$REMOTE_HEAD"
  else
    error "branch '$REBASE_TARGET' not found and remote HEAD is unavailable"
    exit 1
  fi
fi

if [[ "$WORK_BRANCH" == "$BASE_BRANCH" ]]; then
  info "Fast-forwarding '$WORK_BRANCH' from '$REBASE_TARGET'"
  git branch --set-upstream-to="$REBASE_TARGET" "$WORK_BRANCH" >/dev/null 2>&1 || true
  git merge --ff-only "$REBASE_TARGET"
else
  info "Rebasing '$WORK_BRANCH' onto '$REBASE_TARGET'"
  git rebase --autostash "$REBASE_TARGET"
fi

info "Done"
