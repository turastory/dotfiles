# 성능 리뷰 관점 (RIDI 모노레포)

performance-reviewer가 로드한다. 처리량·지연·자원 차원만 본다. 마이크로 최적화 취향은 nit로만.

## 무엇을 보는가

원리: **입력이 커질 때 무엇이 선형 이상으로 늘어나는가**를 본다. 실제 데이터 규모(대형 테이블, 대량 이벤트)를 가정하고 판단한다.

- **N+1 / 쿼리 폭발** — 루프 안 쿼리, resolver의 per-item fetch(dataloader 부재), Knex `whereIn` 대신 반복 조회. GraphQL 필드 resolver의 fan-out.
- **인덱스 / 쿼리 형태** — WHERE 없는 카운트/스캔, 인덱스 미사용 조건, 대형 테이블 full scan, `SELECT *`로 불필요 컬럼, 페이지네이션 없는 대량 조회.
- **replica vs primary** — 읽기는 replica 기본. freshness 명목의 primary 남발은 과한 부하(정합성은 원자적 claim으로). 반대로 쓰기 직후 읽기 정합성 필요한데 replica lag 무시.
- **Kafka subscriber / 배치 처리량** — 메시지당 동기 외부호출, 배치 미사용, 무한 재시도/poison pill로 파티션 정체, 커밋 경계.
- **불필요한 반복/할당** — 중첩 루프, 매 요청 재계산(캐시 후보), 큰 배열 복사, 정규식/직렬화 반복.
- **캐싱 / 메모이제이션** — 캐시 무효화 정확성(성능과 정합성 트레이드오프), 캐시 스탬피드.
- **네트워크 / I/O** — 직렬 await 체인(병렬화 가능), 과도한 왕복, 페이로드 크기(GraphQL over-fetch).
- **프론트(web)** — 번들/렌더 비용, 불필요 리렌더, SSR 데이터 중복 요청(books-islands 이중 호출 이력).

## RIDI 특유 함정

- prod DB는 대형 테이블 다수. WHERE 없는 COUNT/full scan은 실서비스 위험 — 쿼리 형태를 실데이터 규모로 평가.
- 서브스크라이버는 처리량이 곧 지연으로 누적. 메시지당 비용을 본다.
- 이중 호출(예: 결제 요청 프론트→백 직결로 제거한 이력)처럼 왕복 제거 여지.

## 심각도 기준

hot path(요청당·메시지당 반복 실행) + 규모 증가에 취약 = `major`~`blocker`. 저빈도 경로·소규모 = `minor`. 취향/미세개선 = `nit`. 측정 없이 추정이면 confidence low로 명시하고 "확인 방법"을 suggestion에 적는다.

## 출력

report-format.md의 finding 스키마. dimension은 `"performance"`. 가능하면 복잡도/규모 가정(예: "N=주문수, 루프당 1쿼리")을 description에 적는다.
