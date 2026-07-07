# 보안 리뷰 관점 (RIDI 모노레포)

security-reviewer가 로드한다. 취약점·데이터 노출·권한 차원만 본다.

## 무엇을 보는가

원리: **신뢰 경계를 넘는 입력**과 **권한/비밀의 취급**을 추적한다. "될 것 같다"가 아니라 구체적 악용 시나리오(입력→피해)를 재현 가능한 형태로 적는다.

- **인젝션** — SQL(Knex raw, PHP PDO 문자열 조립), 커맨드, path traversal, template(twig) 인젝션. 파라미터 바인딩 우회 여부.
- **인증/인가(authz)** — 새 엔드포인트/resolver/gRPC handler에 권한 체크가 있는가. IDOR(다른 유저의 리소스 id로 접근). 관리자/백오피스 경로의 권한 게이트.
- **결제·금전 surface** — RIDI 핵심 위험지대. 주문/결제/포인트/캐시/쿠폰/리워드 금액이 **클라이언트 입력을 신뢰**하지 않는지, 서버 재계산·검증하는지. 금액 위변조, 중복 지급(idempotency), 음수/오버플로.
- **민감정보 노출** — 로그/에러 응답/GraphQL 필드로 PII·토큰·내부 식별자 유출. 과도한 필드 노출.
- **비밀·크리덴셜** — 하드코딩된 키/토큰, 커밋된 secret, 잘못된 env 취급(예: OAUTH 키 리터럴 처리 이슈).
- **SSRF / 외부요청** — 유저 제어 URL로의 서버 요청, 리다이렉트 검증.
- **입력 검증** — 경계에서의 검증 부재, 신뢰되지 않은 역직렬화, 대량요청/DoS 유발 파라미터(무제한 limit).
- **인가된 데이터의 전파** — 이벤트/subscriber/외부 시스템(CRM)로 민감정보가 필요 이상 흘러가는지.

## RIDI 특유 함정

- 결제 화면은 surface가 여러 개(인앱 웹뷰 / 작품홈 즉시결제 / 웹 /order/checkout 레거시). 권한·금액 검증이 어느 계층에서 이뤄지는지 혼동 금지.
- PHP PDO의 affected rows는 기본 changed rows — 보안 로직에서 "0이면 실패"로 단정하면 우회 가능(정확한 의미 확인).
- GraphQL은 필드 단위 노출 통제. resolver가 상위 authz를 우회해 하위 필드로 데이터를 흘리는지.

## 심각도 기준

악용 가능성 × 피해 크기. 인증 우회·금액 위변조·PII 대량노출·RCE = `blocker`. 조건부/저확률 악용 = `major`/`minor`. 방어적 개선 제안 = `nit`. confidence를 반드시 명시(추정이면 low).

## 출력

report-format.md의 finding 스키마. dimension은 `"security"`. failure_scenario(구체적 입력→피해)를 description에 반드시 포함.
