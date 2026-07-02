---
name: task-batch-to-pr-tree
description: >-
  Turns a batch of loosely-related work items — Asana tasks, Slack threads/links,
  Figma links, or even a plain freeform text list — into a tree of PRs implemented
  by parallel subagents. Use whenever the user hands over multiple tasks at once
  (e.g. "여기 Asana 태스크들 처리해줘", "이 Slack 스레드들 다 구현해서 PR로 올려줘",
  a pasted list of bugs/features) and wants them scoped, grouped into PR-sized
  chunks, built in isolated worktrees, and opened as draft PRs — not just a single
  task. Do NOT use this for a single well-scoped task; go implement it directly.
  Composes pr-tree (tree bookkeeping), superset-cli (worktree creation), and
  create-pr (PR conventions) rather than reimplementing them.
---

# Task Batch → PR Tree

여러 개의 느슨하게 연관된 작업 항목(Asana task, Slack 스레드/링크, Figma 링크, 혹은 그냥
평문 텍스트 목록)을 받아서 **① 항목별 컨텍스트 확보 → ② PR 단위로 그룹핑(트리 스케치) →
③ 청크별 서브에이전트 위임(워크트리+구현+draft PR) → ④ 트리 갱신+리포트** 로 처리한다.

이 스킬은 오케스트레이션 레이어다. 트리 정의/점검은 `pr-tree`, 워크트리 생성은
`superset-cli`, draft PR 작성은 `create-pr`에 그대로 위임한다 — 그 스킬들의 내부 규칙을
여기서 다시 설명하지 않는다. 각 단계에서 해당 스킬을 실제로 invoke할 것.

판단 기준은 "항목 개수"가 아니라 "결과적으로 독립된 PR이 여러 개 필요한가"다. 항목이
하나여도 서로 무관한 여러 영역을 건드려 PR을 나눠야 하면 이 스킬을 쓴다. 반대로 항목이
여러 개여도 사실상 하나의 PR로 묶이고 워크트리 위임까지 갈 필요가 없으면 과하다 — 그냥
직접 구현한다.

## 0. 워크스페이스 준비

**배치 = 워크스페이스 하나로 새로 만들지 않는다.** 먼저 항목마다 기존에 관련 프로젝트가
있는지 확인한다: `~/workspaces/project/*/`를 훑어 각 프로젝트의 `pr-tree.tsv`(branch
prefix, 예 `productpay/event-participation/...`)나 `notes.md`/디렉토리 이름이 이 항목의
기능 영역과 겹치는지 본다. 겹치면 **그 기존 프로젝트가 이 항목의 홈**이다 — 새로 만들지
않고, 그 프로젝트의 기존 `pr-tree.tsv`에 행을 추가하고, 기존 branch prefix(예:
`checkout-use-point`)를 그대로 재사용한다. 새 세그먼트를 지어내기 전에 반드시 기존
브랜치/워크스페이스에서 비슷한 이름이 있는지 먼저 찾는다(`git branch -r | grep
productpay/`, `ls ~/workspaces/project/`).

기존 프로젝트에 매칭되지 않는 항목들만 모아서 새 배치 워크스페이스
`~/workspaces/project/<date>-<name>/`를 만든다(`<date>`는 `YYYY-MM-DD`, `<name>`은 배치를
대표하는 짧은 이름, 예: `2026-07-02-misc-batch`). 즉 한 배치가 기존 트리 여러 개에 행을
얹으면서 동시에 새 트리 하나를 만드는 것도 정상이다 — 항목 수만큼 워크스페이스가 갈릴 수
있다는 뜻이니 4단계에서 영향받는 워크스페이스 전부를 챙긴다.

각 대상 워크스페이스(기존이든 신규든)에 두 파일을 유지한다:
- `pr-tree.tsv` — 신규면 `pr-tree` 스킬의 `templates/pr-tree.tsv`를 복사, 기존이면 그대로
  이어 쓴다. **그 프로젝트의 단일 소스**이므로 이 배치 때문에 새로 쪼개지 않는다.
- `notes.md` — 원본 작업 항목 목록(소스 링크 포함)과 배치 이유/맥락을 짧게 기록. 나중에
  "이 PR이 어떤 요청에서 나왔더라"를 되짚을 근거.

## 1. 항목별 컨텍스트 확보

각 작업 항목을 소스에 맞게 읽는다. 소스 종류를 가정하지 말고 실제로 무엇이 주어졌는지로 분기:

- **Asana task**: `mcp__claude_ai_Asana` 도구(`get_task`/`get_tasks`)로 설명·커스텀 필드·코멘트를 읽는다.
- **Slack 스레드/링크**: `slack:slack-search`, `slack_read_thread` 등으로 스레드 전체 맥락을 읽는다.
- **Figma 링크**: figma MCP의 `get_design_context`/`get_screenshot`으로 디자인 스펙을 확인.
- **평문 텍스트**: 주어진 그대로가 스펙이다 — 추가 조회 없이 진행하되, 텍스트 안에 링크가
  섞여 있으면 그 링크도 위 방식대로 따라간다.

각 항목 안에 있는 **연관 링크**(Slack 스레드가 언급하는 다른 Asana task, Asana task
설명에 박힌 Figma 링크 등)를 따라가서 스코프를 명확히 한다. 항목 하나당 결과물은 스코프
한 줄~한 문단 노트: 무엇을 바꿔야 하는지, 짐작 가능하면 영향 받는 영역/파일, 다른 항목과의
의존 관계 단서.

이 단계는 항목 수가 많으면(대략 5개 이상) 병렬 서브에이전트로 나눠 조사해도 되지만,
작으면 직접 순회해서 읽는 게 더 빠르다.

## 2. 그룹핑 → PR 트리 스케치

확보한 스코프 노트를 놓고 두 기준으로 항목을 청크(=PR 하나)로 묶는다:

1. **같은 PR로 묶일 수 있는가** — 같은 파일/영역을 건드리거나, 따로 나누면 리뷰 단위로
   부자연스러운 항목들.
2. **병렬로 갈 수 있는가, 아니면 쌓여야(stacked) 하는가** — 청크 B가 청크 A의 결과물(공통
   타입, 새 API, 새 컬럼 등)에 의존하면 B의 base는 A의 branch.

결과를 `pr-tree.tsv`에 바로 채운다(`pr-tree` 스킬의 포맷을 그대로 따름):
- 이 시점엔 아직 구현 전이므로 `pr` 컬럼은 `-`, `status`는 `planned`.
- `base`는 `master`(루트 청크) 또는 다른 행의 `branch`(의존 청크) — 여러 root가 있는
  forest여도 무방하다.
- `branch`는 레포 컨벤션(`productpay/<feature>/<details>`)을 따르되, 0단계에서 확인한
  기존 `<feature>` 세그먼트가 있으면 그대로 재사용한다(새로 짓지 않는다). 실제 브랜치는
  3단계에서 생성.

그룹핑 결과와 근거(왜 이렇게 나눴는지)를 `notes.md`에 짧게 남긴다. 확정 전에 사용자에게
스케치를 보여주고 확인받는다 — 그룹 경계는 되돌리기 번거로우므로(이미 위임된 뒤 재편은
파일 재분배 문제가 됨) 여기서 한 번 맞추는 게 싸다.

## 3. 청크별 위임

**2단계 결과 청크가 1개뿐이면 위임하지 않는다.** 별도 워크트리를 만들어 서브에이전트에게
넘기는 건 여러 청크를 병렬로 굴릴 때 이득이 있는 구조다 — 청크가 하나면 그 이점이 없고
위임 왕복(컨텍스트 전달, 완료 대기, 결과 취합)만 비용으로 남는다. 이 경우 현재 세션에서
바로 구현하고, 필요하면 브랜치만 새로 파서(`superset-cli`로 워크트리를 만들지 여부는
상황에 맞게 판단) `create-pr`로 draft PR을 연다. 아래 위임 절차는 청크가 2개 이상일 때만
적용한다.

청크가 여러 개면 각 청크를 독립 에이전트에게 맡긴다. 에이전트가 할 일(순서대로):

1. **워크트리 생성** — `superset-cli` 스킬대로 `superset workspaces create --project ridi
   --local --branch <branch> --base-branch <base>`. base가 다른 청크의 branch면(stacked),
   그 청크의 branch가 이미 push된 뒤에 실행해야 한다.
2. **구현** — 1단계 스코프 노트를 그대로 프롬프트에 포함시켜 넘긴다. 관련 프로젝트 스킬
   (`ridi-test-guides`, `ridi-graphql-structure` 등 해당되는 것)을 읽고 따르도록 위임
   프롬프트에 명시.
3. **draft PR 오픈** — `create-pr` 스킬 컨벤션대로. PR 본문에 **원본 작업 항목 링크**(Asana
   task URL, Slack permalink 등)를 반드시 포함시키도록 위임 프롬프트에 명시 — 나중에
   4단계 리포트와 리뷰어가 맥락을 되짚을 유일한 연결고리다. 항목이 평문 텍스트라 링크가
   없으면 원본 요청 문구를 그대로 인용한다.

위임 전에 각 항목의 성격을 한 번 더 본다 — CS/장애성 버그처럼 즉시 대응이 필요해 보이는
항목은 이 배치 파이프라인(워크트리 생성~draft PR까지 비동기로 흘러가는)에 태우기 전에
사용자에게 먼저 확인한다. 백로그성 작업과 인시던트 대응을 같은 fan-out에 섞으면 인시던트가
불필요하게 늦어질 수 있다.

### Workflow 도구 vs 수동 Agent 호출

청크가 몇 개 안 되고(대략 3개 이하) 대부분 독립적이면, `Agent` 도구를 청크마다 하나씩
병렬 호출하는 것으로 충분하다 — 사용자가 각 에이전트를 개별적으로 지켜보고 개입하기 쉽다.

청크 수가 많거나, stacked 의존성이 여러 레벨이라 "이 청크는 저 청크의 branch가 push된
뒤에만 시작 가능"한 순서 제약이 있으면 `Workflow` 도구가 더 적합하다:
- 같은 레벨(서로 base가 같은 형제 청크)은 `parallel()`.
- 부모→자식으로 이어지는 stacked 체인은 `pipeline()` — 각 단계가 이전 단계의 PR/branch
  정보를 받아 자기 워크트리의 base로 쓴다.
- `isolation: 'worktree'`는 쓰지 않는다 — 각 청크가 이미 자기 전용 워크트리를
  `superset workspaces create`로 만들기 때문에 중복이다.

`Workflow` 도구는 실제 워크트리 생성과 draft PR 오픈까지 이어지는, 되돌리기 번거로운
작업을 다수 병렬로 실행한다. 호출 전에 그룹핑 스케치(2단계)를 사용자에게 보여주고 진행
승인을 받은 뒤에 호출한다.

## 4. 트리 갱신 + 리포트

각 위임이 끝나면 실제 PR 번호/브랜치로 해당 청크가 속한 `pr-tree.tsv`의 `pr`/`status`
(→`open`)를 채운다. 0단계에서 항목이 기존 프로젝트 여러 개와 신규 배치 워크스페이스로
갈렸다면, **영향받은 워크스페이스마다** 각각 갱신하고 각각 점검기를 돌린다 — 한 배치가
여러 `pr-tree.tsv`를 건드리는 게 정상이다:

```bash
~/.agents/skills/pr-tree/check-pr-tree.sh --tree ~/workspaces/project/<name>/pr-tree.tsv
```

`RESULT: OK`가 아니면 원인(브랜치 미푸시, base 어긋남 등)을 해당 청크 담당 위임의
후속 조치로 처리한다.

마지막으로 사용자에게 **원본 작업 항목 기준**으로 리포트한다: 각 항목이 어느 청크/PR로
구현됐는지, PR 링크, 트리에서의 위치(어떤 base 위에 있는지). 여러 항목이 한 PR에 묶였으면
그 PR 링크를 여러 번 나열해도 된다 — 항목 → PR의 매핑이 끊기지 않는 게 중요하다.
