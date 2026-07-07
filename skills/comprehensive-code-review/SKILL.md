---
name: comprehensive-code-review
description: RIDI 코드 변경(주로 PR, 없으면 브랜치 diff)을 architecture·security·performance·style 4개 관점의 전문 리뷰어가 병렬 검토하고 GitHub pending review까지 남겨야 할 때 사용. "종합 코드 리뷰", "전체 리뷰", "4개 관점 리뷰", "병렬 리뷰", "아키텍처+보안+성능+스타일 리뷰", "이 PR 종합적으로 리뷰해줘", "comprehensive review", "PR 통합 리뷰", "리뷰 리포트 만들어줘" 요청 시 사용. 리뷰 재실행/업데이트/보완, "보안 관점만 다시", "아까 리뷰 다시", "리포트 개선" 같은 후속 요청도 포함. 단일 관점 빠른 지적이나 diff 한 줄 확인은 기존 code-review/review-pr로 충분.
---

# 종합 코드 리뷰 하네스 (RIDI)

4개 관점 전문 리뷰어를 **병렬·독립** 실행하고 1개 synthesizer가 findings를 병합한 뒤, PR 대상이면 **GitHub pending review comment를 실제로 남긴다**. 독립 실행은 성능이자 품질 장치다 — 리뷰어끼리 서로의 결론에 anchoring되지 않아야 관점별 커버리지가 온전히 나온다.

**실행 모드: 하이브리드 (팬아웃=서브 에이전트 병렬 → 팬인=synthesizer 서브 에이전트)**
리뷰어 간 실시간 통신(SendMessage)은 일부러 쓰지 않는다. 결과는 파일로 모으고 synthesizer가 병합한다.

## 에이전트 로스터

| 에이전트 | 역할 | 로드하는 reference |
|---|---|---|
| `architecture-reviewer` | 설계·책임 분리·경계·결합도 | `references/architecture.md` |
| `security-reviewer` | 취약점·권한·데이터 노출·결제 surface | `references/security.md` |
| `performance-reviewer` | N+1·쿼리·replica·subscriber 처리량 | `references/performance.md` |
| `style-reviewer` | 네이밍·컨벤션·타입·죽은코드·주석 | `references/style.md` |
| `review-synthesizer` | 4개 리포트 병합·중복제거·상충병기·정렬·pending comment 후보 생성 | `references/report-format.md`, `assets/report-template.md`, `../review-pr/SKILL.md`, `../my-tone/SKILL.md` |

모든 Agent 호출은 `model: "opus"`, `subagent_type: "general-purpose"`(gh/스크립트 실행 필요).

## 워크플로우

### Phase 0: 컨텍스트 확인 (초기/후속/부분 재실행 판별)

작업 디렉토리 하위 `.review-workspace/` 존재 여부로 실행 모드를 정한다:
- **미존재** → 초기 실행.
- **존재 + 사용자가 "보안만 다시" 등 부분 재실행** → 해당 리뷰어만 재호출하고 synthesizer 재실행. 나머지 finding JSON은 재사용.
- **존재 + 새 대상(다른 PR)** → 기존 `.review-workspace/`를 `.review-workspace_prev/`로 옮기고 새로 시작.

`.review-workspace/`는 커밋되면 안 된다. repo 루트의 `.gitignore`에 없으면 사용자에게 알리거나 스크래치패드 경로를 대신 쓴다.

### Phase 1: 대상 수집

`scripts/collect-changes.sh <target> <workspace>` 를 실행한다.
- `target`: 사용자가 준 PR 번호/URL. 없으면 `auto`(현재 브랜치 PR → 없으면 master diff 폴백).
- 산출물: `.review-workspace/{meta.json, changed-files.txt, full.diff}`.
- 변경 파일이 0개면 리뷰 중단하고 사용자에게 보고.
- 변경 규모가 매우 크면(예: 수백 파일) 사용자에게 범위 좁힐지 확인.

### Phase 2: 팬아웃 — 4개 리뷰어 병렬 실행

4개 리뷰어를 **한 메시지에서 동시에** `Agent` 호출한다(`run_in_background: true`, `model: "opus"`). 각 리뷰어에게 전달할 것:
- `.review-workspace/` 경로(full.diff, changed-files.txt, meta.json 위치)
- 자신의 reference 파일 경로 하나
- repo 절대경로 (변경 파일의 주변 맥락을 직접 열어 확인하도록 — diff만으로 판단 금지)
- 산출 경로 규약: `{NN}_{dimension}_findings.json` + `{NN}_{dimension}.md` (NN은 01~04 고정 배정)

리뷰어는 diff에 더해 **실제 파일을 열어 맥락을 확인**한다(호출부/타입/주변 관용구). RIDI 팀 컨벤션이 필요하면 `review-pr` 스킬을 invoke한다.

### Phase 3: 팬인 — synthesizer 병합 + pending comment 후보 생성

4개 리뷰어가 모두 끝나면(또는 재시도 후에도 실패한 것을 제외하고) `review-synthesizer`를 `Agent`로 1회 호출한다. 입력은 `.review-workspace/*_findings.json` 전부. 출력은 통합 리포트(사용자 지정 경로 또는 `.review-workspace/REVIEW-REPORT.md`).

synthesizer는 리포트와 별도로 `.review-workspace/review-comments.json`을 반드시 만든다.
- GitHub inline으로 달 수 있는 actionable finding만 포함한다.
- report-only 항목(넓은 설계 논쟁, diff line이 없는 설명, confidence low 확인 요청)은 리포트에는 남기되 `review-comments.json`에서는 제외한다.
- 각 comment body는 `review-pr`의 메타 태그 형식(`🏷 <카테고리> · <경중> · <연관도>`)과 `my-tone`의 AI footer 규칙을 따른다. Codex로 실행 중이면 각 본문 끝에 `_Sent by Codex_`를 붙인다.
- 같은 file:line에 여러 관점 finding이 모이면 comment 1개로 병합한다.
- 최종 comment line은 PR head diff 기준으로 다시 확인한다. stale line이면 올리지 말고 리포트의 "pending review 제외"에 이유를 적는다.

### Phase 4: GitHub pending review 생성

대상이 PR이면 `scripts/post-pending-review.sh .review-workspace`를 실행해 `review-comments.json`을 GitHub pending review로 실제 생성한다.

규칙:
- PR 모드(`meta.json.mode == "pr"`)가 아니면 pending review를 만들 수 없으므로 리포트만 남기고 사용자에게 명시한다.
- `review-comments.json`이 빈 배열이면 pending review를 만들지 않는다. 억지 comment를 만들지 않는다.
- `gh auth status`를 먼저 확인한다. 인증 실패는 직접 우회하지 말고 사용자에게 보고한다.
- payload에는 `event`를 넣지 않는다. GitHub가 review를 `PENDING` 상태로 남기게 하기 위함이다.
- 생성 후 review id, state, comment count를 확인한다. state가 `PENDING`이 아니면 실패로 보고한다.
- submit은 절대 하지 않는다. 사용자가 GitHub에서 검토 후 직접 submit한다.

### Phase 5: 결과 제시 + 진화 제안

통합 리포트 요약(심각도 집계 + blocker 목록), pending review 생성 결과(review id/state/comment count), 전체 리포트 경로를 사용자에게 제시한다. 이어서 피드백 기회를 제공한다("리뷰 깊이/관점 구성/리포트 형식에서 바꾸고 싶은 점 있나요?"). 강요하지 않되 반드시 기회를 준다.

## 데이터 전달 프로토콜

**파일 기반(산출물) + 반환값 기반(상태)**. 리뷰어는 서브 에이전트이므로 팀 메시지 대신 파일로 결과를 남기고, Agent 반환 메시지로 완료/실패를 알린다.
- 중간 산출물: `.review-workspace/` (보존 — 감사 추적·부분 재실행용).
- 파일명: `{phase}_{agent}_{artifact}` 규약. 최종 리포트만 사용자 지정 경로로.
- pending review 입력: `.review-workspace/review-comments.json` (GitHub Review API comments 배열).
- pending review 결과: `.review-workspace/pending-review-result.json` (review id, state, comment count).

## 에러 핸들링

핵심 원칙: **1회 재시도 → 재실패 시 그 관점 없이 진행하고 리포트에 누락 명시**. 상충 데이터는 삭제하지 않고 출처 병기.

| 상황 | 대응 |
|---|---|
| `collect-changes.sh` 실패(gh 인증 등) | 사용자에게 원인 보고. gh 인증 필요 시 `gh auth status` 안내(직접 뚫지 말 것). diff 폴백 가능하면 제안. |
| 리뷰어 1개 실패/타임아웃 | 1회 재시도. 재실패 시 나머지 3개로 진행, synthesizer가 "이 관점 리뷰되지 않음" 명시. |
| 리뷰어가 빈 결과 | 정상. `[]` finding으로 "무발견" 처리(누락과 구분). |
| synthesizer 실패 | 재시도. 재실패 시 리뷰어 원본 md들을 그대로 사용자에게 안내(병합 불발 명시). |
| pending review 생성 실패 | 원인(`gh auth`, stale line, invalid payload)을 보고하고, `.review-workspace/review-comments.json` 경로를 안내한다. 이미 생성된 pending review가 있으면 삭제하지 않는다. |
| 변경 0건 | 리뷰 중단, 사용자 보고. |

## 테스트 시나리오

**정상 흐름**: `/이 PR 종합 리뷰해줘 #12345` → collect-changes가 PR #12345 diff 수집 → 4개 리뷰어 병렬 → 각 findings.json 생성 → synthesizer가 심각도순 통합 리포트와 review-comments.json 생성 → post-pending-review.sh가 pending review 생성 → 요약 제시. 기대: blocker/major가 상단, 중복 지적 병합, 관점 태그 부착, GitHub review state는 PENDING.

**에러 흐름**: security-reviewer가 타임아웃 → 1회 재시도 후 재실패 → architecture/performance/style 3개로 진행 → 통합 리포트 "리뷰되지 않은 부분: security" 명시. 기대: 나머지 리포트는 정상 생성, 누락이 사용자에게 분명히 전달.

## 후속 작업

- **부분 재실행**: "보안 관점만 다시" → security-reviewer만 재호출, 기존 나머지 findings.json 재사용, synthesizer 재실행.
- **리포트/코멘트 개선**: synthesizer만 재호출(리뷰어 재실행 불필요). 이미 GitHub에 생성된 pending review가 있으면 중복 게시하지 말고 기존 pending review를 삭제/재생성할지 사용자에게 확인한다.
- **관점 추가/제거**: 에이전트 추가/삭제 후 이 SKILL.md의 로스터·Phase 2 팬아웃 목록 갱신, CLAUDE.md 변경 이력 기록.
