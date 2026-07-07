# Finding 스키마 & 통합 리포트 포맷

모든 리뷰어와 synthesizer가 공유하는 데이터 계약. 리뷰어는 이 스키마로 산출물을 내고, synthesizer는 이 스키마로 병합한 뒤 pending review 입력을 만든다.

## Finding 스키마 (리뷰어 산출)

각 리뷰어는 `_workspace/{NN}_{dimension}_findings.json` 에 finding 배열(JSON)을,
`_workspace/{NN}_{dimension}.md` 에 사람이 읽는 요약을 함께 쓴다.
JSON이 synthesizer의 입력(병합·정렬용), md는 감사 추적용이다.

```json
[
  {
    "dimension": "architecture | security | performance | style",
    "severity": "blocker | major | minor | nit",
    "title": "한 줄 요약 (무엇이 문제인가)",
    "file": "repo 기준 상대경로",
    "line": 123,
    "description": "무엇이/왜 문제인지. security는 구체적 악용 시나리오(입력→피해), performance는 규모 가정 포함.",
    "suggestion": "구체적 개선 방향(코드 전체 아닌 방향/일부/pseudo).",
    "confidence": "high | medium | low"
  }
]
```

규칙:
- diff에 실제로 포함된 변경만 대상. 기존 코드 문제는 변경이 직접 건드리거나 악화시킨 경우만.
- 발견이 없으면 빈 배열 `[]`을 쓴다(파일은 반드시 생성 — synthesizer가 "리뷰됨/무발견"을 구분).
- 확신 없으면 confidence를 낮추고 "확인 방법"을 suggestion에 적는다. 억지로 만들지 않는다.

## 심각도 정의 (공통)

| severity | 의미 | 예 |
|---|---|---|
| `blocker` | 머지 전 반드시 수정 | 인증 우회, 금액 위변조, 데이터 유실, hot-path N+1로 장애 위험 |
| `major` | 머지 전 수정 강력 권장 | 조건부 취약점, 명확한 성능 저하, 책임 경계 붕괴 |
| `minor` | 개선 권장, 블로킹 아님 | 국소 성능, 설계 트레이드오프, 타입 구멍 |
| `nit` | 취향/사소 | 네이밍 제안, 미세 정리 |

## 통합 리포트 구조 (synthesizer 산출)

`assets/report-template.md` 템플릿을 채운다. 핵심 규칙:

1. **중복 제거** — 같은 file:line을 여러 리뷰어가 지적하면 하나로 합치되, 기여한 dimension을 모두 병기.
2. **상충은 삭제하지 않고 병기** — 리뷰어 간 판단이 엇갈리면(예: architecture는 추출 권장 vs style은 과분리 우려) 양쪽 출처를 함께 남기고 판단은 독자에게.
3. **심각도순 정렬** — blocker → major → minor → nit. 동급이면 file 경로순.
4. **요약 먼저** — 상단에 심각도별·관점별 집계 표. 바쁜 리뷰어가 blocker만 보고도 판단 가능하게.
5. **누락 명시** — 실행 실패/타임아웃으로 빠진 리뷰어가 있으면 "이 관점은 리뷰되지 않음"을 명시(무발견과 구분).
6. **각 항목에 출처 dimension 태그** — 독자가 관심 관점만 필터 가능.

## Pending review comment 스키마 (synthesizer 산출)

`.review-workspace/review-comments.json`은 GitHub Review API의 `comments` 배열에 바로 넣을 수 있는 JSON 배열이다.

```json
[
  {
    "path": "repo 기준 상대경로",
    "line": 123,
    "side": "RIGHT",
    "body": "🏷 로직 · 중요 · 이번 PR\n\n코멘트 본문...\n\n_Sent by Codex_"
  }
]
```

규칙:
- PR head diff에 존재하는 새 라인만 포함한다. stale line, deleted line, diff 밖 파일은 제외한다.
- `side`는 기본 `RIGHT`를 쓴다. 정말 필요한 경우에만 GitHub Review API 형식에 맞춰 `start_line` 등 추가 필드를 쓴다.
- body 첫 줄은 `review-pr`의 메타 태그 형식을 따른다.
- body 끝에는 `my-tone`의 AI footer를 붙인다. Codex로 실행 중이면 `_Sent by Codex_`.
- confidence가 `low`인 finding은 기본적으로 리포트에만 남긴다. 사용자가 명시적으로 원하면 확인 요청 코멘트로 바꿀 수 있다.
- blocker/major는 우선 포함한다. minor/nit은 실제로 리뷰어가 행동할 수 있는 경우만 포함한다.
