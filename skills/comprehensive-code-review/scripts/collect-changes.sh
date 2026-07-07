#!/usr/bin/env bash
# collect-changes.sh — 리뷰 대상(PR/브랜치 diff)을 확정해 _workspace/에 산출물로 떨어뜨린다.
#
# 사용법:
#   collect-changes.sh <target> <workspace_dir>
#     target       : PR 번호 | PR URL | "diff"(브랜치 diff 강제) | "auto"(빈값과 동일)
#     workspace_dir: 산출물 디렉토리 (예: <repo>/.review-workspace)
#
# 산출물:
#   $WS/meta.json        : {mode, pr_number, base, head, head_oid, repo, title, changed_count}
#   $WS/changed-files.txt : 변경된 파일 경로 목록 (한 줄에 하나)
#   $WS/full.diff        : 전체 unified diff
#
# 출력은 verbose + machine-readable. 각 단계의 시작/결과를 명확히 찍는다.
set -euo pipefail

TARGET="${1:-auto}"
WS="${2:-}"

log() { printf '[collect-changes] %s\n' "$*"; }
fail() { printf '[collect-changes][ERROR] %s\n' "$*" >&2; exit 1; }

[ -n "$WS" ] || fail "workspace_dir(두 번째 인자) 필수"
mkdir -p "$WS"
log "workspace=$WS target=$TARGET"

# --- 의존성 확인 (설치되어 있다고 가정하지 않는다) ---
command -v git >/dev/null 2>&1 || fail "git 미설치"
HAS_GH=0
if command -v gh >/dev/null 2>&1; then HAS_GH=1; else log "gh 미설치 → PR 모드 불가, diff 폴백만 가능"; fi
HAS_JQ=0
if command -v jq >/dev/null 2>&1; then HAS_JQ=1; else log "jq 미설치 → meta.json은 최소 필드만 기록"; fi

BASE_BRANCH="${REVIEW_BASE_BRANCH:-master}"

emit_meta() {
  # $1 mode $2 pr $3 base $4 head $5 title $6 head_oid $7 repo
  local count; count=$(wc -l < "$WS/changed-files.txt" | tr -d ' ')
  if [ "$HAS_JQ" -eq 1 ]; then
    jq -n --arg mode "$1" --arg pr "$2" --arg base "$3" --arg head "$4" \
          --arg title "$5" --arg head_oid "$6" --arg repo "$7" --argjson count "${count:-0}" \
      '{mode:$mode, pr_number:$pr, base:$base, head:$head, head_oid:$head_oid, repo:$repo, title:$title, changed_count:$count}' \
      > "$WS/meta.json"
  else
    printf '{"mode":"%s","pr_number":"%s","base":"%s","head":"%s","head_oid":"%s","repo":"%s","changed_count":%s}\n' \
      "$1" "$2" "$3" "$4" "$6" "$7" "${count:-0}" > "$WS/meta.json"
  fi
  log "meta.json 기록 완료 (mode=$1, changed=$count, head_oid=$6, repo=$7)"
}

resolve_pr() {
  # PR 번호/URL이 주어졌거나, auto에서 현재 브랜치의 PR이 잡히면 PR 모드.
  local ref="$1"
  [ "$HAS_GH" -eq 1 ] || return 1
  gh auth status >/dev/null 2>&1 || { log "gh 인증 안 됨 (gh auth status 실패)"; return 1; }

  local pr_json
  if ! pr_json=$(gh pr view "$ref" --json number,title,baseRefName,headRefName,headRefOid 2>/dev/null); then
    return 1
  fi

  local num base head title head_oid repo
  if [ "$HAS_JQ" -eq 1 ]; then
    num=$(printf '%s' "$pr_json" | jq -r '.number')
    title=$(printf '%s' "$pr_json" | jq -r '.title')
    base=$(printf '%s' "$pr_json" | jq -r '.baseRefName')
    head=$(printf '%s' "$pr_json" | jq -r '.headRefName')
    head_oid=$(printf '%s' "$pr_json" | jq -r '.headRefOid')
  else
    num=$(gh pr view "$ref" --json number -q .number)
    title=$(gh pr view "$ref" --json title -q .title)
    base=$(gh pr view "$ref" --json baseRefName -q .baseRefName)
    head=$(gh pr view "$ref" --json headRefName -q .headRefName)
    head_oid=$(gh pr view "$ref" --json headRefOid -q .headRefOid)
  fi
  repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)

  log "PR 모드: #$num ($title) base=$base head=$head head_oid=$head_oid repo=$repo"
  gh pr diff "$num" --name-only > "$WS/changed-files.txt"
  gh pr diff "$num" > "$WS/full.diff"
  emit_meta "pr" "$num" "$base" "$head" "$title" "$head_oid" "$repo"
  return 0
}

resolve_diff() {
  log "diff 모드: git diff $BASE_BRANCH...HEAD"
  # 3-dot: merge-base 기준. 실제 도입/변경분만.
  git diff "$BASE_BRANCH...HEAD" --name-only > "$WS/changed-files.txt" 2>/dev/null \
    || fail "git diff 실패 ($BASE_BRANCH 존재 여부 확인)"
  git diff "$BASE_BRANCH...HEAD" > "$WS/full.diff"
  local head head_oid repo
  head=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  head_oid=$(git rev-parse HEAD 2>/dev/null || echo "")
  repo=""
  if [ "$HAS_GH" -eq 1 ]; then
    repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
  fi
  emit_meta "diff" "" "$BASE_BRANCH" "$head" "" "$head_oid" "$repo"
}

case "$TARGET" in
  diff)
    resolve_diff ;;
  auto|"")
    if resolve_pr "" ; then :; else log "현재 브랜치 PR 없음 → diff 폴백"; resolve_diff; fi ;;
  *)
    if resolve_pr "$TARGET" ; then :; else fail "PR 해석 실패: $TARGET (gh 인증/PR 존재 확인)"; fi ;;
esac

log "완료. changed-files=$WS/changed-files.txt full.diff=$WS/full.diff meta=$WS/meta.json"
