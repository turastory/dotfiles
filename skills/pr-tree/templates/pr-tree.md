# <기능명> — PR 트리

<한 줄 설명>. **트리 정의의 single source of truth는 옆의 [`pr-tree.tsv`](./pr-tree.tsv)**. 점검·cascade는 `pr-tree` 스킬 스크립트로 돈다.

## 공통 계약 (전 PR 동일)

- **Feature Flag:** `productpay-<content>-<date>` (기본 OFF → 회귀 0)
- **식별자/저장 이름:** <canonical 식별자> (synonym 금지)
- <기타 공통 계약>

## 현재 트리

```
master
 ├─ PR1  #0000  <root>       [OPEN]    ← trunk, base=master
 │   └─ PR2     <child>      [PLANNED] base=PR1
 └─ ...                                독립 PR이면 base=master
```

| PR | 역할 | branch (suffix) | base | 상태 |
|---|---|---|---|---|
| #0000 | ... | `…/<root>` | `master` | OPEN |

worktree 절대경로 = `~/.superset/worktrees/ridi/<worktree_suffix>`.

**랜딩 순서:** ...

## 점검 / cascade

```bash
~/.agents/skills/pr-tree/check-pr-tree.sh --tree "$(dirname "$0")/pr-tree.tsv"   # 점검
~/.agents/skills/pr-tree/check-pr-tree.sh --tree <...> --plan                     # cascade 명령
```

cascade 규칙·tree 주의점은 `pr-tree` 스킬 SKILL.md 참고.

## 주의/히스토리

- YYYY-MM-DD: ...
