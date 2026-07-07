# 코드 스타일/컨벤션 리뷰 관점 (RIDI 모노레포)

style-reviewer가 로드한다. 가독성·컨벤션·유지보수성 차원만 본다. 설계(architecture)·정확성 버그(다른 리뷰어)와 겹치면 넘긴다.

## 무엇을 보는가

원리: **다음 사람이 읽고 고칠 때의 비용**을 줄이는가. 포매터가 자동으로 잡는 것(들여쓰기 등)은 지적하지 않는다 — 포매터가 소유한다.

- **포매터 위임** — TS/JS는 Biome(`biome.json`), `frontends/app`은 ESLint+Prettier, Python은 isort+black, PHP는 PHP-CS-Fixer. 순수 포맷 이슈는 "포매터가 처리"로 넘기고, 포매터가 못 잡는 것에 집중.
- **네이밍** — 이름이 역할을 말하는가. 축약·오해 소지·도메인 용어 불일치. RIDI 컨벤션은 `review-pr` 스킬 기준을 따른다.
- **타입 안전성** — `any`/과도한 단언(`as`), 좁힐 수 있는 타입, nullable 처리 누락, 옵셔널 남용. GraphQL/proto 생성 타입과의 정합.
- **죽은 코드 / 미사용** — 미사용 import·변수·함수, 도달 불가 분기, 남은 디버그 로그, 주석 처리된 코드.
- **주석** — 현재 상태만 설명하는가(변경 이력·"기존엔 X→Y" 금지). 왜(why)를 남겼는가, 자명한 what 중복 아닌가. comment rot(코드와 어긋난 주석).
- **일관성** — 주변 코드의 관용구·패턴과 맞는가(에러 핸들링 방식, 반환 형태, 파일 배치). 혼자 튀는 스타일.
- **에러 핸들링 표면** — silent failure(빈 catch, 삼킨 에러), 부적절한 fallback으로 실패 은폐. (심층은 correctness지만 표면적 패턴은 여기서.)
- **PR 범위 / 원자성** — 무관한 변경 섞임, 리뷰 어려운 거대 커밋. 리팩토링과 기능이 뒤섞였는지.
- **테스트 스타일** — 있다면: fixture 배치, assertion 스타일, feature flag describe 분리 등 RIDI 테스트 컨벤션(`ridi-test-guides`) 위반. (커버리지 충분성은 별도 관심사.)

## 팀 컨벤션 위임

RIDI 네이밍·쿼리 스타일·주석·PR 범위·타입 안전성 등 팀 기준은 **`review-pr` 스킬을 invoke**해 따른다. 테스트 컨벤션은 `ridi-test-guides`. 여기서 중복 기술하지 않고, 스킬 기준으로 판정한다.

## 심각도 기준

스타일은 대부분 `minor`/`nit`. 예외: 타입 안전성 구멍이나 silent failure로 실제 버그 가능성이 있으면 `major`(단, correctness 성격이면 그 취지를 명시). 순수 취향은 nit, 강제하지 않는다.

## 출력

report-format.md의 finding 스키마. dimension은 `"style"`. 포매터가 자동 수정하는 항목은 finding으로 내지 말 것.
