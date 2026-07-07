# 코드 리뷰 리포트 — {대상: PR #N "제목" / 브랜치 diff}

- **대상**: {mode} · base `{base}` ← head `{head}`
- **변경 규모**: {changed_count} files
- **리뷰 관점**: architecture · security · performance · style
- **pending review**: {생성됨 review #{id}, comments {n}개 / 생성 안 함: 사유}
- **생성**: {날짜}

## 요약

| 관점 | blocker | major | minor | nit | 상태 |
|---|---|---|---|---|---|
| architecture | 0 | 0 | 0 | 0 | ✅ 리뷰됨 / ⚠️ 누락 |
| security | 0 | 0 | 0 | 0 | |
| performance | 0 | 0 | 0 | 0 | |
| style | 0 | 0 | 0 | 0 | |
| **합계** | | | | | |

{한 문단: 전반 평가 + 머지 가능 여부(blocker 존재 시 머지 불가) + 가장 중요한 1~3개.}

---

## 🔴 Blocker

### 1. {title}
- **관점**: security {여러 관점이 지적했으면 나열}
- **위치**: `path/to/file.ts:123`
- **문제**: {description — 악용 시나리오/규모 가정 포함}
- **제안**: {suggestion}
- **confidence**: high

---

## 🟠 Major

{동일 형식}

---

## 🟡 Minor

{동일 형식. 간결히.}

---

## ⚪ Nit

- `file:line` — {title} (style)

---

## ⚖️ 상충/논쟁 항목

{리뷰어 간 판단이 엇갈린 항목. 양쪽 출처 병기. 없으면 이 섹션 생략.}

---

## 리뷰되지 않은 부분

{실행 실패/타임아웃으로 빠진 관점이나 파일. 없으면 "없음".}

---

## Pending review 제외

{리포트에는 남겼지만 GitHub inline comment로 올리지 않은 finding과 이유. 예: diff line 없음, confidence low, report-only 설계 논의, stale line. 없으면 "없음".}
