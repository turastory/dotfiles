---
name: pr-tree
description: Use when managing a tree/forest of dependent PRs — defining the tree, checking whether each branch is in sync with its base, or cascading master/base changes upward. Covers stacked PRs (a linear chain is just a degenerate tree) and forests with multiple roots. Pairs with sync-with-master for the per-branch merge.
---

# PR Tree

여러 PR이 서로 base로 물려 있는 **트리(tree/forest)** 를 deterministic하게 관리한다. 한 trunk 위에 여러 가지가 갈라지고 별도 root에서 독립 PR이 나오는 구조가 일반형이고, 선형 체인(`A→B→C`, 흔히 "stacked PRs")은 가지가 하나뿐인 **트리의 특수 케이스**다. 둘을 같은 방식으로 다룬다.

핵심 아이디어: **트리 정의를 `pr-tree.tsv` 한 파일(single source of truth)에 두고**, 점검·cascade는 그 파일을 읽는 스크립트로 돌린다. 사람이 머릿속 휴리스틱으로 "이게 base가 뭐였더라"를 추적하지 않는다.

## When to use

- 사용자가 의존 PR 트리/체인(stacked PRs 포함)을 만들거나 추적할 때
- master(또는 하위 base)가 바뀌어 그 변경을 트리 위로 흘려보내야(cascade) 할 때
- "트리/스택 상태 점검", "각 브랜치가 base 포함하는지", "어디부터 다시 머지해야 하는지" 물을 때
- 새 PR을 트리에 추가/제거하거나 base가 머지돼 체인이 이동했을 때

개별 브랜치 하나를 master와 맞추는 단순 작업은 `sync-with-master` 스킬을 쓴다. 이 스킬은 그 위에서 **여러 브랜치의 의존 관계 전체**를 관리한다.

## 구성물

- `check-pr-tree.sh` — 범용 점검기(read-only, deterministic). repo/worktree-root는 env로 override, gh repo 슬러그는 origin remote에서 자동 추출.
- `templates/pr-tree.tsv`, `templates/pr-tree.md` — 새 트리 부트스트랩용 템플릿.

스크립트는 이 스킬에 **한 벌만** 둔다. 각 프로젝트는 **데이터(`pr-tree.tsv`)와 설명(`pr-tree.md`)만** 워크스페이스(`~/workspaces/project/<name>/`)에 두고, 점검은 이 스킬의 스크립트를 `--tree`로 가리켜 실행한다.

## pr-tree.tsv 포맷 (single source of truth)

탭 구분 5컬럼. `#` 주석·빈 줄 무시.

```
# pr	branch	base	worktree_suffix	status
28798	productpay/checkout-use-point/inapp-toggle	master	productpay/checkout-use-point/inapp-toggle	open
-	productpay/checkout-use-point/serial-popup	master	-	planned
-	productpay/checkout-use-point/order-rental-purchase-label	productpay/checkout-use-point/inapp-toggle	-	planned
```

- **pr** — PR 번호, 없으면 `-`.
- **base** — `master`(루트) 또는 **다른 행의 branch**(명시). 이 명시 덕분에 선형 체인이든 가지가 갈라지든 한 로직으로 점검된다. 선형 체인이면 base를 바로 윗 행의 branch로 적으면 된다.
- **worktree_suffix** — `$RIDI_WT_ROOT`(기본 `~/.superset/worktrees/ridi`) 아래 상대경로. 없으면 `-`.
- **status** — `open`(점검 대상) | `planned`(미착수, `⊘`로 건너뜀). 머지돼 트리를 벗어난 PR은 행을 **삭제**한다.

트리가 바뀌면 이 파일만 고친다 → 스크립트·문서가 따라온다.

## 사용법

```bash
# 점검 (워크스페이스 프로젝트 디렉토리에서, 또는 --tree 으로 경로 지정)
~/.agents/skills/pr-tree/check-pr-tree.sh --tree ~/workspaces/project/<name>/pr-tree.tsv
~/.agents/skills/pr-tree/check-pr-tree.sh --tree <...> --no-fetch   # fetch 생략
~/.agents/skills/pr-tree/check-pr-tree.sh --tree <...> --plan       # + cascade 명령 출력
```

점검 항목(open 행만): ① `origin/<branch>` 존재 ② `origin/<base>` 존재 ③ origin 무결성(child가 base 포함, base-ahead==0) ④ local==origin(push 누락) ⑤ gh PR base/상태 일치(best-effort). 전부 통과면 `RESULT: OK` + exit 0, 아니면 `DRIFT` + exit 1.

## 새 트리 부트스트랩

1. `~/workspaces/project/<name>/` 에 `templates/pr-tree.tsv`·`pr-tree.md`를 복사해 채운다(브랜치/base/PR 번호).
2. 점검 스크립트를 한 번 돌려 `RESULT: OK` 확인.
3. `pr-tree.md`에 트리 그림·공통 계약(FF 키 등)·랜딩 순서·히스토리를 적는다.

## Cascade (동기화)

master 변경이나 하위 브랜치 신규 커밋을 트리 위로 흘려보낼 때. **순서: root→leaf**(루트에 가까운 것부터). 각 단계는 직속 base를 머지 후 push하고, 다음 단계가 그 갱신된 base를 머지한다.

1. `--plan` 으로 cascade 명령을 받는다(이미 포함이면 `Already up to date` no-op이라 전체 실행 안전).
2. 순서대로 실행. 각 머지 전 직속 base 워크트리 push가 끝났는지 확인.
3. 다시 점검해서 `RESULT: OK` 확인.

규칙:
- base가 `master`면 `origin/master` 머지(로컬 master는 다른 worktree에 묶여 stale). feature base는 로컬 ref 머지(worktree 간 공유).
- merge 커밋은 `--no-edit`. **충돌 해결 후 마무리 커밋은 `git commit --no-verify`** — 대량 머지에서 lint-staged hook이 무관 파일로 죽으며 index가 손상된 사례가 있다.
- 이 repo는 rebase 대신 merge commit 사용.

## tree/forest 주의점

- base가 `master`인 행이 여러 개일 수 있다(독립 root PR). 한 branch가 여러 자식의 base가 될 수도 있다(가지 분기).
- base PR이 머지되면 그 행을 삭제하고, 자식 행의 base를 (머지된 PR의 base였던) 상위로 올린다 → 보통 `master`. 스크립트가 `origin/<base> 없음`으로 이를 잡아준다.
- 점검은 tsv 행 순서대로 돈다. cascade가 의미 있으려면 **base가 자식보다 앞 행**에 오도록 topological하게 정렬해 둔다(루트 → 잎).

## env override

`RIDI_REPO`(기본 `~/ridi/ridi`), `RIDI_WT_ROOT`(기본 `~/.superset/worktrees/ridi`), `GH_REPO`(기본: origin URL 자동 추출), `BASE_ROOT`(기본 `master`).
