#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEFAULT_UPSTREAM_REMOTE="upstream"
DEFAULT_ORIGIN_REMOTE="origin"
DEFAULT_UPSTREAM_URL="https://github.com/zeroclaw-labs/zeroclaw.git"
DEFAULT_BASE_BRANCH="main"
GITHUB_USER_CONFIG_KEY="zeroclaw.github-user"

cd "${REPO_ROOT}"

usage() {
  cat <<'USAGE'
Git easy workflow helper for fork + upstream projects.

Usage:
  scripts/git_easy.sh               # interactive menu
  scripts/git_easy.sh init [user]   # configure remotes and save GitHub user
  scripts/git_easy.sh sync          # sync current branch with upstream
  scripts/git_easy.sh start <branch># sync main, then switch/create feature branch
  scripts/git_easy.sh publish       # push current branch to origin
  scripts/git_easy.sh doctor        # show workflow health
  scripts/git_easy.sh help

Examples:
  scripts/git_easy.sh init Yishow
  scripts/git_easy.sh start feat/my-feature
  scripts/git_easy.sh sync
  scripts/git_easy.sh publish
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

current_branch() {
  git symbolic-ref --quiet --short HEAD
}

get_saved_user() {
  git config --get "${GITHUB_USER_CONFIG_KEY}" || true
}

save_user() {
  local user="$1"
  git config "${GITHUB_USER_CONFIG_KEY}" "${user}"
}

build_origin_url() {
  local user="$1"
  echo "https://github.com/${user}/zeroclaw.git"
}

ensure_upstream() {
  if git remote get-url "${DEFAULT_UPSTREAM_REMOTE}" >/dev/null 2>&1; then
    return
  fi

  info "Adding ${DEFAULT_UPSTREAM_REMOTE} -> ${DEFAULT_UPSTREAM_URL}"
  git remote add "${DEFAULT_UPSTREAM_REMOTE}" "${DEFAULT_UPSTREAM_URL}"
}

ensure_origin() {
  local user="$1"
  local origin_url
  origin_url="$(build_origin_url "${user}")"

  if git remote get-url "${DEFAULT_ORIGIN_REMOTE}" >/dev/null 2>&1; then
    info "Setting ${DEFAULT_ORIGIN_REMOTE} -> ${origin_url}"
    git remote set-url "${DEFAULT_ORIGIN_REMOTE}" "${origin_url}"
  else
    info "Adding ${DEFAULT_ORIGIN_REMOTE} -> ${origin_url}"
    git remote add "${DEFAULT_ORIGIN_REMOTE}" "${origin_url}"
  fi
}

verify_remote() {
  local remote_name="$1"
  git ls-remote --exit-code "${remote_name}" HEAD >/dev/null 2>&1
}

sync_current_branch() {
  local saved_user="$1"
  local -a cmd=(
    "${SCRIPT_DIR}/git_upsync.sh"
    --upstream-url "${DEFAULT_UPSTREAM_URL}"
    --remote "${DEFAULT_UPSTREAM_REMOTE}"
    --origin-remote "${DEFAULT_ORIGIN_REMOTE}"
    --base-branch "${DEFAULT_BASE_BRANCH}"
  )

  if [[ -n "${saved_user}" ]]; then
    cmd+=(--origin-url "$(build_origin_url "${saved_user}")")
  fi

  "${cmd[@]}"
}

init_cmd() {
  local user="${1:-$(get_saved_user)}"

  if [[ -z "${user}" ]]; then
    read -r -p "GitHub user: " user
  fi

  if [[ -z "${user}" ]]; then
    error "GitHub user is required"
    exit 1
  fi

  ensure_upstream
  ensure_origin "${user}"
  save_user "${user}"

  git fetch --prune "${DEFAULT_UPSTREAM_REMOTE}"
  git branch --set-upstream-to="${DEFAULT_UPSTREAM_REMOTE}/${DEFAULT_BASE_BRANCH}" "${DEFAULT_BASE_BRANCH}" >/dev/null 2>&1 || true

  if verify_remote "${DEFAULT_UPSTREAM_REMOTE}"; then
    info "${DEFAULT_UPSTREAM_REMOTE} reachable"
  else
    warn "${DEFAULT_UPSTREAM_REMOTE} unreachable"
  fi

  if verify_remote "${DEFAULT_ORIGIN_REMOTE}"; then
    info "${DEFAULT_ORIGIN_REMOTE} reachable"
  else
    warn "${DEFAULT_ORIGIN_REMOTE} unreachable"
  fi

  info "Saved GitHub user: ${user}"
}

sync_cmd() {
  local saved_user
  saved_user="$(get_saved_user)"
  sync_current_branch "${saved_user}"
}

start_cmd() {
  local branch="${1:-}"
  local saved_user
  saved_user="$(get_saved_user)"

  if [[ -z "${branch}" ]]; then
    read -r -p "Feature branch name: " branch
  fi

  if [[ -z "${branch}" ]]; then
    error "Feature branch name is required"
    exit 1
  fi

  info "Switching to ${DEFAULT_BASE_BRANCH}"
  git switch "${DEFAULT_BASE_BRANCH}"
  sync_current_branch "${saved_user}"

  if git show-ref --verify --quiet "refs/heads/${branch}"; then
    info "Switching to existing branch ${branch}"
    git switch "${branch}"
  else
    info "Creating branch ${branch}"
    git switch -c "${branch}"
  fi

  if [[ "${branch}" != "${DEFAULT_BASE_BRANCH}" ]]; then
    sync_current_branch "${saved_user}"
  fi
}

publish_cmd() {
  local branch
  branch="$(current_branch)"

  if [[ "${branch}" == "${DEFAULT_BASE_BRANCH}" ]]; then
    error "Refuse to publish ${DEFAULT_BASE_BRANCH}. Use a feature branch."
    exit 1
  fi

  if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    info "Pushing with --force-with-lease to keep rebase workflow clean"
    git push --force-with-lease
  else
    info "Publishing ${branch} to ${DEFAULT_ORIGIN_REMOTE}"
    git push -u "${DEFAULT_ORIGIN_REMOTE}" "${branch}"
  fi
}

doctor_cmd() {
  local saved_user
  saved_user="$(get_saved_user)"

  echo "GitHub user (saved): ${saved_user:-<not set>}"
  echo
  git remote -v
  echo
  git status -sb
  echo
  if verify_remote "${DEFAULT_UPSTREAM_REMOTE}"; then
    echo "upstream: reachable"
  else
    echo "upstream: unreachable"
  fi
  if verify_remote "${DEFAULT_ORIGIN_REMOTE}"; then
    echo "origin: reachable"
  else
    echo "origin: unreachable"
  fi
}

menu() {
  while true; do
    echo
    echo "Git Easy Menu"
    echo "1) Init remotes and user"
    echo "2) Sync current branch"
    echo "3) Start or switch feature branch"
    echo "4) Publish current branch"
    echo "5) Doctor check"
    echo "0) Exit"
    read -r -p "Choose: " choice

    case "${choice}" in
      1) init_cmd ;;
      2) sync_cmd ;;
      3) start_cmd ;;
      4) publish_cmd ;;
      5) doctor_cmd ;;
      0) exit 0 ;;
      *) warn "Unknown option: ${choice}" ;;
    esac
  done
}

main() {
  local cmd="${1:-menu}"
  shift || true

  case "${cmd}" in
    init) init_cmd "${1:-}" ;;
    sync) sync_cmd ;;
    start) start_cmd "${1:-}" ;;
    publish) publish_cmd ;;
    doctor) doctor_cmd ;;
    menu) menu ;;
    help|-h|--help) usage ;;
    *) error "Unknown command: ${cmd}"; echo; usage; exit 1 ;;
  esac
}

main "$@"
