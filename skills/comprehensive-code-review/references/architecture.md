# 아키텍처 리뷰 관점 (RIDI 모노레포)

architecture-reviewer가 로드한다. 설계·구조 차원만 본다. 스타일/보안/성능은 다른 리뷰어 담당이므로 겹치면 한 줄만 남기고 넘긴다.

## 무엇을 보는가

원리: 변경이 **경계와 책임을 흐리는가**를 본다. 동작하는 코드라도 결합도를 높이거나 레이어를 깨면 결함이다.

- **책임 분리 / 응집도** — 한 함수·모듈·클래스가 여러 책임을 지는가. 반대로 억지로 쪼개서 파라미터만 늘었는가(RIDI 컨벤션: 섣부른 분리 지양, 파라미터 과다·Map 파라미터 회피).
- **모듈/앱 경계** — RIDI는 앱 경계가 뚜렷하다. `backends/`(TS GraphQL/REST/subscriber/batch), `ridi1/`(레거시 PHP), `frontends/web`, `internal-products/`(백오피스 NestJS gRPC). 한 변경이 경계를 넘나들며 양쪽 내부에 손대면 왜 그런지 근거가 있어야 한다.
- **레이어 위반 / 순환 의존** — resolver→service→query(Knex) 흐름 역행, subscriber가 API 계층 직접 호출, 도메인 로직이 컨트롤러/twig로 샌 경우.
- **추상화 수준의 적절성** — 지금 필요 없는 일반화(over-engineering), 혹은 반대로 복붙된 로직이 세 번째 등장(추출 시점).
- **데이터 흐름 / 상태** — 이벤트(Outbox/subscriber), GraphQL federation, PHP↔SSR(books-islands) 경계에서 데이터가 어디서 만들어지고 누가 소유하는가. 이중 소스/이중 호출.
- **확장성·변경 용이성** — 새 요구가 오면 이 설계가 어디를 강제로 뜯게 만드는가. feature flag가 필요한 유저 영향 지점인데 없는가(RIDI: 유저 사이드 영향 시 flag 고려, `backends/src/utils/featureFlags/values.ts`).
- **하위호환** — GraphQL SDL은 additive-only(기존 필드 nullability/이름 변경 금지). proto 메시지 필드 재사용/번호 변경. DB 마이그레이션의 되돌림 가능성.

## RIDI 특유 함정

- 결제/주문 surface는 "모던 라우트가 보인다"고 라이브가 아니다. 레거시 books-backend twig 렌더 경로가 실제인 경우가 있다 — 아키텍처 판단 전 실제 렌더 경로 확인.
- Kafka subscriber는 poison pill에 취약. objective/action_data 누락이 subscriber 전체를 막을 수 있는 구조인지.
- 서브스크라이버/배치의 primary vs replica 조회 선택은 정합성 설계 문제(원자적 claim으로 풀지, primary 남발 아님).

## 팀 컨벤션 위임

RIDI 리뷰 체크리스트(네이밍은 style 담당이지만 책임 분리·죽은 코드·PR 범위·subscriber 설계 항목)는 **`review-pr` 스킬을 invoke**해 기준을 따른다. 여기서 중복 기술하지 않는다.

## 출력

각 발견을 report-format.md의 finding 스키마로 낸다. dimension은 `"architecture"`. 설계 트레이드오프는 확정 결함이 아니면 severity `minor`+confidence 명시.
