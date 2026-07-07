#!/usr/bin/env bash
# post-pending-review.sh — .review-workspace/review-comments.json을 GitHub pending review로 생성한다.
#
# 사용법:
#   post-pending-review.sh <workspace_dir>
#
# 입력:
#   $WS/meta.json            : collect-changes.sh 산출물. PR 모드여야 한다.
#   $WS/review-comments.json : GitHub Review API comments 배열.
#
# 출력:
#   $WS/review-payload.json
#   $WS/pending-review-response.json
#   $WS/pending-review-result.json
set -euo pipefail

WS="${1:-}"

log() { printf '[post-pending-review] %s\n' "$*"; }
fail() { printf '[post-pending-review][ERROR] %s\n' "$*" >&2; exit 1; }

[ -n "$WS" ] || fail "workspace_dir(첫 번째 인자) 필수"
[ -d "$WS" ] || fail "workspace_dir 없음: $WS"

META="$WS/meta.json"
COMMENTS="$WS/review-comments.json"
PAYLOAD="$WS/review-payload.json"
RESPONSE_FILE="$WS/pending-review-response.json"
RESULT="$WS/pending-review-result.json"

command -v python3 >/dev/null 2>&1 || fail "python3 미설치"

[ -f "$META" ] || fail "meta.json 없음: $META"
[ -f "$COMMENTS" ] || fail "review-comments.json 없음: $COMMENTS"

read_meta_field() {
  python3 - "$META" "$1" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get(sys.argv[2]) or "")
PY
}

MODE=$(read_meta_field mode)
PR_NUMBER=$(read_meta_field pr_number)
HEAD_OID=$(read_meta_field head_oid)
REPO=$(read_meta_field repo)

if [ "$MODE" != "pr" ] || [ -z "$PR_NUMBER" ]; then
  log "PR 모드가 아니므로 pending review 생성 생략 (mode=$MODE)"
  exit 0
fi

COMMENT_COUNT=$(python3 - "$COMMENTS" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    comments = json.load(f)
if not isinstance(comments, list):
    raise SystemExit("review-comments.json must be a JSON array")
print(len(comments))
PY
)

if [ "$COMMENT_COUNT" -eq 0 ]; then
  log "게시할 comment가 없어 pending review 생성 생략"
  exit 0
fi

command -v gh >/dev/null 2>&1 || fail "gh 미설치"
gh auth status >/dev/null 2>&1 || fail "gh 인증 안 됨. gh auth status를 확인하세요."

if [ -z "$HEAD_OID" ]; then
  log "meta.json에 head_oid 없음. gh pr view로 재조회"
  HEAD_OID=$(gh pr view "$PR_NUMBER" --json headRefOid -q .headRefOid)
fi

if [ -z "$REPO" ]; then
  REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
fi

log "payload 생성 시작 pr=$PR_NUMBER head_oid=$HEAD_OID repo=$REPO comments=$COMMENT_COUNT"
python3 - "$COMMENTS" "$PAYLOAD" "$HEAD_OID" <<'PY'
import json
import sys

comments_path, payload_path, head_oid = sys.argv[1:4]
with open(comments_path, encoding="utf-8") as f:
    comments = json.load(f)

if not isinstance(comments, list):
    raise SystemExit("review-comments.json must be a JSON array")

normalized = []
for index, comment in enumerate(comments, start=1):
    if not isinstance(comment, dict):
        raise SystemExit(f"comment #{index} must be an object")
    for key in ("path", "line", "body"):
        if key not in comment:
            raise SystemExit(f"comment #{index} missing required key: {key}")
    body = str(comment["body"])
    if "_Sent by " not in body:
        raise SystemExit(f"comment #{index} missing AI footer")
    normalized_comment = {
        "path": str(comment["path"]),
        "line": int(comment["line"]),
        "side": str(comment.get("side") or "RIGHT"),
        "body": body,
    }
    for optional_key in ("start_line", "start_side"):
        if optional_key in comment:
            normalized_comment[optional_key] = comment[optional_key]
    normalized.append(normalized_comment)

payload = {
    "commit_id": head_oid,
    "comments": normalized,
}
with open(payload_path, "w", encoding="utf-8") as f:
    json.dump(payload, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

log "GitHub pending review 생성 요청"
RESPONSE=$(gh api "repos/$REPO/pulls/$PR_NUMBER/reviews" --input "$PAYLOAD")
printf '%s\n' "$RESPONSE" > "$RESPONSE_FILE"

REVIEW_ID=$(python3 - "$RESPONSE_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("id") or "")
PY
)
STATE=$(python3 - "$RESPONSE_FILE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(data.get("state") or "")
PY
)

[ -n "$REVIEW_ID" ] || fail "review id 확인 실패: $RESPONSE_FILE"
[ "$STATE" = "PENDING" ] || fail "review state가 PENDING이 아님: $STATE"

COMMENTS_RESPONSE="$WS/pending-review-comments.json"
gh api "repos/$REPO/pulls/$PR_NUMBER/reviews/$REVIEW_ID/comments" > "$COMMENTS_RESPONSE"
CREATED_COUNT=$(python3 - "$COMMENTS_RESPONSE" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
print(len(data))
PY
)

[ "$CREATED_COUNT" -eq "$COMMENT_COUNT" ] || fail "요청 comment 수($COMMENT_COUNT)와 생성 comment 수($CREATED_COUNT)가 다름"

python3 - "$RESULT" "$PR_NUMBER" "$REPO" "$HEAD_OID" "$REVIEW_ID" "$STATE" "$CREATED_COUNT" <<'PY'
import json
import sys

result_path, pr_number, repo, head_oid, review_id, state, comment_count = sys.argv[1:8]
with open(result_path, "w", encoding="utf-8") as f:
    json.dump(
        {
            "pr_number": pr_number,
            "repo": repo,
            "head_oid": head_oid,
            "review_id": review_id,
            "state": state,
            "comment_count": int(comment_count),
        },
        f,
        ensure_ascii=False,
        indent=2,
    )
    f.write("\n")
PY

log "완료 review_id=$REVIEW_ID state=$STATE comments=$CREATED_COUNT result=$RESULT"
