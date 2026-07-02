#!/usr/bin/env bash
# PR 트리 상태 점검 (deterministic, read-only). pr-tree 스킬의 범용 점검기.
#
#   사용:
#     check-pr-tree.sh --tree <pr-tree.tsv>             # fetch 후 전체 점검
#     check-pr-tree.sh --tree <...> --no-fetch          # fetch 생략(직전 fetch 재사용)
#     check-pr-tree.sh --tree <...> --plan              # 어긋난 구간 cascade 명령 출력(실행 안 함)
#   --tree 생략 시 $PWD/pr-tree.tsv 를 읽는다.
#
# 트리 정의는 pr-tree.tsv 한 곳에서만 읽는다(single source of truth).
# 선형 체인이든 tree(forest)든 각 행의 base를 명시하므로 동일 로직으로 점검한다.
# 순수 git ref 계산 + gh PR base 조회만 한다(휴리스틱 없음). 어긋나면 exit 1.
#
# tsv 컬럼(탭 구분): pr <TAB> branch <TAB> base <TAB> worktree_suffix <TAB> status
#   - pr: PR 번호 또는 '-'(아직 없음)
#   - base: master(루트) 또는 다른 행의 branch
#   - worktree_suffix: $RIDI_WT_ROOT 아래 상대경로, '-'면 미생성
#   - status: open(브랜치/PR 존재, 점검 대상) | planned(미착수, ⊘ 건너뜀)
#   '#' 시작 줄과 빈 줄은 무시한다.
#
# env override:
#   RIDI_REPO     점검 대상 repo 경로 (기본 ~/ridi/ridi)
#   RIDI_WT_ROOT  worktree 루트 (기본 ~/.superset/worktrees/ridi)
#   GH_REPO       gh용 owner/repo 슬러그 (기본: origin remote에서 자동 추출)
#   BASE_ROOT     루트 base 이름 (기본 master)
set -u

TREE_FILE="$PWD/pr-tree.tsv"
REPO="${RIDI_REPO:-$HOME/ridi/ridi}"
WT_ROOT="${RIDI_WT_ROOT:-$HOME/.superset/worktrees/ridi}"
BASE_ROOT="${BASE_ROOT:-master}"

DO_FETCH=1; DO_PLAN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --tree)    TREE_FILE="$2"; shift 2 ;;
    --tree=*)  TREE_FILE="${1#*=}"; shift ;;
    --no-fetch) DO_FETCH=0; shift ;;
    --plan)     DO_PLAN=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -f "$TREE_FILE" ] || { echo "FATAL: tree file not found: $TREE_FILE" >&2; exit 2; }
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || { echo "FATAL: not a git repo: $REPO" >&2; exit 2; }
g() { git -C "$REPO" "$@"; }

# gh repo 슬러그: env 우선, 없으면 origin remote URL에서 owner/repo 추출
if [ -z "${GH_REPO:-}" ]; then
  origin_url="$(g config --get remote.origin.url 2>/dev/null || true)"
  # git@host:owner/repo.git  또는  https://host/owner/repo.git  → owner/repo
  origin_url="${origin_url%.git}"
  GH_REPO="$(printf '%s' "$origin_url" | sed -E 's#^.*[:/]([^/:]+/[^/]+)$#\1#')"
fi

# --- 트리 정의 읽기 (주석/빈 줄 제외) ---
PRS=(); BRANCHES=(); BASES=(); WTS=(); STATUSES=()
while IFS=$'\t' read -r pr branch base wt status; do
  [ -z "${pr:-}" ] && continue
  case "$pr" in \#*) continue ;; esac
  PRS+=("$pr"); BRANCHES+=("$branch"); BASES+=("$base"); WTS+=("$wt"); STATUSES+=("${status:-open}")
done < "$TREE_FILE"
N=${#BRANCHES[@]}
[ "$N" -gt 0 ] || { echo "FATAL: empty tree" >&2; exit 2; }

# tsv에 이미 추적 중인 branch인가 (master 포함)
in_tree() {
  local b="$1" i
  [ "$b" = "$BASE_ROOT" ] && return 0
  for ((i=0; i<N; i++)); do [ "${BRANCHES[$i]}" = "$b" ] && return 0; done
  return 1
}

# tsv에 이미 추적 중인 branch인가 (master 제외 — master는 누구나의 base라 후보 판정에 못 씀)
in_tree_branch() {
  local b="$1" i
  for ((i=0; i<N; i++)); do [ "${BRANCHES[$i]}" = "$b" ] && return 0; done
  return 1
}

# --- tsv의 base 관계로부터 트리(forest) 그림 출력 (git/gh 조회 없이 정적으로 그림) ---
VISITED=(); for ((i=0; i<N; i++)); do VISITED[$i]=0; done
print_tree_children() {
  local parent="$1" prefix="$2" i ci idx=0 count=0
  local -a kids=()
  for ((i=0; i<N; i++)); do [ "${BASES[$i]}" = "$parent" ] && kids+=("$i"); done
  count=${#kids[@]}
  [ "$count" -gt 0 ] || return 0
  for ci in "${kids[@]}"; do
    idx=$((idx+1))
    VISITED[$ci]=1
    local branch="${BRANCHES[$ci]}" pr="${PRS[$ci]}" st="${STATUSES[$ci]}" short connector childprefix label
    short="${branch##*/}"
    if [ "$idx" = "$count" ]; then connector="└─"; childprefix="${prefix}   "
    else connector="├─"; childprefix="${prefix}│  "
    fi
    label="$short"
    [ "$pr" != "-" ] && label="$label (#$pr)"
    [ "$st" = "planned" ] && label="$label ⊘planned"
    echo "${prefix}${connector} ${label}"
    print_tree_children "$branch" "$childprefix"
  done
}
echo "-- 트리 구조 --"
echo "$BASE_ROOT"
print_tree_children "$BASE_ROOT" ""
for ((i=0; i<N; i++)); do
  [ "${VISITED[$i]}" = 0 ] && echo "  ⚠ ${BRANCHES[$i]} — base '${BASES[$i]}' 연결 안 됨 (오탈자/누락 확인)"
done
echo

echo "== PR 트리 점검 =="
echo "repo: $REPO  (gh: ${GH_REPO:-?})"
echo "tree: $TREE_FILE ($N branches)"

if [ "$DO_FETCH" = 1 ]; then
  echo "-- fetch origin --prune"
  g fetch origin --prune --quiet 2>/dev/null || { echo "FATAL: fetch 실패" >&2; exit 2; }
fi
echo "origin/$BASE_ROOT tip: $(g rev-parse --short "origin/$BASE_ROOT") $(g log -1 --format=%s "origin/$BASE_ROOT")"
echo

HAS_GH=0; command -v gh >/dev/null 2>&1 && HAS_GH=1

fail=0
declare -a PLAN
for ((i=0; i<N; i++)); do
  pr="${PRS[$i]}"; br="${BRANCHES[$i]}"; base="${BASES[$i]}"; wt="${WTS[$i]}"; st="${STATUSES[$i]}"
  short="${br##*/}"

  if [ "$st" = "planned" ]; then
    echo "[$short] ⊘ 미착수 (planned, base: ${base##*/}) — 건너뜀"
    continue
  fi

  echo "[$short] (PR #$pr, base: ${base##*/})"

  if ! g rev-parse --verify -q "origin/$br" >/dev/null; then
    echo "  ✗ origin/$br 없음 (머지됨/삭제됨?) — pr-tree.tsv 갱신 필요"
    fail=1; continue
  fi
  base_ref="origin/$base"
  if ! g rev-parse --verify -q "$base_ref" >/dev/null; then
    echo "  ✗ base $base_ref 없음 — base PR 머지로 체인 이동, pr-tree.tsv 갱신 필요"
    fail=1; continue
  fi

  # cascade recipe (idempotent). base=루트면 stale 로컬 ref 대신 origin/<root> 머지.
  if [ "$base" = "$BASE_ROOT" ]; then merge_ref="origin/$BASE_ROOT"; else merge_ref="$base"; fi
  if [ "$wt" != "-" ]; then
    PLAN+=("cd $WT_ROOT/$wt && git merge $merge_ref --no-edit && git push origin $br")
  fi

  # origin 무결성: child가 base를 포함하는가 (base-ahead == 0)
  read base_ahead child_ahead < <(g rev-list --left-right --count "$base_ref...origin/$br" | awk '{print $1, $2}')
  if [ "$base_ahead" -eq 0 ]; then
    echo "  ✓ origin: base 포함 (child ahead $child_ahead)"
  else
    echo "  ✗ origin: base 미포함 — base가 $base_ahead 커밋 앞섬 → cascade 필요"
    fail=1
  fi

  # local == origin? (워크트리 있고 로컬 ref 존재할 때만)
  if [ "$wt" != "-" ] && g rev-parse --verify -q "$br" >/dev/null; then
    lsha="$(g rev-parse "$br" 2>/dev/null)"; osha="$(g rev-parse "origin/$br")"
    if [ "$lsha" = "$osha" ]; then
      echo "  ✓ local == origin"
    else
      read o_ahead l_ahead < <(g rev-list --left-right --count "origin/$br...$br" 2>/dev/null | awk '{print $1, $2}')
      echo "  ⚠ local≠origin (origin ahead ${o_ahead:-?} / local ahead ${l_ahead:-?}) — push 필요할 수 있음"
      fail=1
    fi
  fi

  # gh: PR base / 상태 (best-effort)
  if [ "$HAS_GH" = 1 ] && [ "$pr" != "-" ] && [ -n "${GH_REPO:-}" ]; then
    if info="$(gh pr view "$pr" --repo "$GH_REPO" --json state,baseRefName,mergeStateStatus -q '[.state,.baseRefName,.mergeStateStatus]|@tsv' 2>/dev/null)"; then
      IFS=$'\t' read -r gh_state gh_base gh_merge <<< "$info"
      [ "$gh_state" = "OPEN" ] || { echo "  ⚠ PR 상태 $gh_state (열려있지 않음)"; fail=1; }
      if [ "$gh_base" != "$base" ]; then
        echo "  ⚠ PR base가 '$gh_base' (기대 '$base') — pr-tree.tsv 와 불일치"
        fail=1
      fi
      [ "$gh_merge" = "CLEAN" ] || echo "  · mergeState: $gh_merge"
    fi
  fi
done

echo
if [ "$fail" = 0 ]; then
  echo "RESULT: OK — 착수된(open) 노드 전부 in-sync (각 child가 base 포함, local==origin)"
else
  echo "RESULT: DRIFT — 위 ✗/⚠ 항목 확인 필요"
fi

# --- 트리 밖 PR 발견: base가 이미 tracked branch인데(master 자체는 제외 — 누구나의 base라 신호가 안 됨) tsv엔 없는 open PR ---
# 제안만 한다 — tsv 추가는 사용자 확인 후 사람(또는 에이전트)이 한다. exit code에는 영향 없음.
if [ "$HAS_GH" = 1 ] && [ -n "${GH_REPO:-}" ]; then
  discovered=0
  while IFS=$'\t' read -r dpr dhead dbase; do
    [ -z "${dpr:-}" ] && continue
    in_tree_branch "$dbase" || continue
    in_tree "$dhead" && continue
    if [ "$discovered" = 0 ]; then
      echo
      echo "-- 트리 밖 PR 발견 (base가 이미 트리에 있음, pr-tree.tsv엔 없음) --"
      discovered=1
    fi
    echo "  🔎 PR #$dpr  $dhead  (base: $dbase) — pr-tree.tsv에 추가할까요?"
  done < <(gh pr list --repo "$GH_REPO" --state open --json number,headRefName,baseRefName -q '.[] | [.number, .headRefName, .baseRefName] | @tsv' 2>/dev/null)
fi

if [ "$DO_PLAN" = 1 ]; then
  echo
  echo "-- cascade 명령 (root→leaf 순서대로 실행; 이미 in-sync면 'Already up to date'로 no-op) --"
  echo "# 각 머지 전 base 워크트리가 push 끝났는지 확인. 충돌 시 해결 후 git commit --no-verify."
  if [ "${#PLAN[@]}" -gt 0 ]; then
    for cmd in "${PLAN[@]}"; do echo "$cmd"; done
  else
    echo "(worktree_suffix가 설정된 행이 없어 cascade 명령 없음)"
  fi
elif [ "$fail" != 0 ]; then
  echo "(cascade 명령 전체 레시피를 보려면 --plan)"
fi
exit "$fail"
