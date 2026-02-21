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
Git Easy（超簡化版）

主流程（只記這三個）:
  git zc start <分支名>   建立/切換功能分支，並先同步 upstream
  git zc sync            同步目前分支（main 走 ff，功能分支走 rebase）
  git zc publish         發布目前分支到 origin

其他指令:
  git zc guide           顯示新手說明與範例
  git zc doctor          檢查 remote 與目前狀態
  git zc init [GitHub帳號] 首次初始化（通常只需一次）
  git zc help

範例:
  git zc start feat/login-ui
  git zc sync
  git zc publish
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

guide_cmd() {
  cat <<'GUIDE'
=== Git Easy 使用說明 ===

你平常只要做 3 件事：
1) 開始新功能：
   git zc start feat/你的功能名

2) 跟上游同步：
   git zc sync

3) 發布到你的 fork：
   git zc publish

工作習慣：
- 不要在 main 直接開發
- main 只拿來同步 upstream/main
- 功能都放在 feat/* 分支

一個完整範例：
  git zc start feat/notification-settings
  # 開發與 commit...
  git zc sync
  # 繼續開發與 commit...
  git zc publish
GUIDE
}

menu() {
  guide_cmd
  while true; do
    echo
    echo "Git Easy Menu（只留常用）"
    echo "1) Start（開始/切換功能分支）"
    echo "2) Sync（同步目前分支）"
    echo "3) Publish（發布目前分支）"
    echo "4) Doctor（檢查狀態）"
    echo "5) Guide（再看一次說明）"
    echo "0) Exit"
    read -r -p "Choose: " choice

    case "${choice}" in
      1) start_cmd ;;
      2) sync_cmd ;;
      3) publish_cmd ;;
      4) doctor_cmd ;;
      5) guide_cmd ;;
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
    guide) guide_cmd ;;
    menu) menu ;;
    help|-h|--help) usage ;;
    *) error "Unknown command: ${cmd}"; echo; usage; exit 1 ;;
  esac
}

main "$@"
