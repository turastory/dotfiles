# books-islands 아키텍처 상세

## 전체 흐름

```
브라우저 → PHP OrderController
  → FrontendAppService::postIslandsRenderVariables() [Node.js로 HTTP POST]
  → booksIslandsRoutes.ts [Express — req.body 명시적 destructure]
  → Islands 서버가 orderCheckoutPrepareData() + renderToReadableStream() 실행
  → JSON 반환: { BonusCashInfo: "<div>...</div>", Ridipay: "<div>...</div>", PreparedData: "<script>...</script>" }
  → PHP가 Twig 템플릿에 {{ islands['Ridipay'] | raw }}로 주입
  → 브라우저가 완성된 HTML 수신
  → client.ts가 hydrate() 호출 → React가 ISLANDS__* div에 attach
```

`checkout.twig` 폴백 패턴:
```twig
{% if islands['BonusCashInfo'] %}
  {{ islands['BonusCashInfo'] | raw }}
{% else %}
  {% include 'order/bonuscash_info.twig' %}
{% endif %}
```

## orderCheckout 구조

체크아웃 페이지는 **2개의 island**을 렌더링한다: `BonusCashInfo`와 `Ridipay`.

### 주요 파일

- **`App.tsx`** — `withApp()`으로 래핑된 2개의 island 컴포넌트 정의
- **`server.tsx`** — `orderCheckoutPrepareData()`가 PHP 파라미터를 React props로 변환, React Query prefetch
- **`client.ts`** — `hydrate()` 호출하여 `ISLANDS__*` DOM 노드 hydration
- **`components/Ridipay/`** — 메인 체크아웃 UI (결제 수단 선택, 카드 목록, 결제 버튼 등)

### 디렉토리 구조

```
src/apps/orderCheckout/
├── App.tsx                 # 메인 export + withApp 래퍼 정의
├── server.tsx              # 서버사이드 데이터 준비 및 렌더링
├── client.ts               # 클라이언트사이드 hydration 엔트리
├── queries/                # React Query 훅 (13개)
├── components/
│   ├── Ridipay/            # 메인 체크아웃 컴포넌트 (~900줄)
│   ├── RidipayContextProvider/
│   ├── PaymentSelect/
│   ├── PaymentDetail/
│   ├── Description/
│   ├── Agreement/
│   └── ...
└── assets/svgs/
```

## 4개 레이어 상세

### 레이어 1: PHP (`OrderController.php`)

- `getOrderCheckoutIslands()` 호출 (307-327줄)에 params 추가
- Twig 전용 데이터는 `$renderer->set()`에 별도 추가

### 레이어 2: Express (`booksIslandsRoutes.ts`)

`frontends/web/ridibooks/src/server/routes/booksIslandsRoutes.ts`

POST body를 명시적으로 destructure — **새 파라미터를 여기에 추가하지 않으면 silently drop됨**:

```ts
const {
  b_ids, total_price, gift, token,
  return_url, return_url_at_fail, pay_object,
  is_mobile, is_in_app, is_tax_deduction_order,
  is_gift_point_policy_enabled, // ← 이런 식으로 명시적 추가 필요
} = req.body as ...;

const context = {
  req, res,
  // boolean 파라미터는 getTruthyValue() 사용 ('0'/'1'/true/'true' 처리)
  is_gift_point_policy_enabled: getTruthyValue(is_gift_point_policy_enabled),
  ...
};
```

### 레이어 3: books-islands

**`server.tsx`:**
```ts
export type OrderCheckoutContextParams = {
  // ... 기존 필드
  is_gift_point_policy_enabled?: boolean; // 추가
};

export const orderCheckoutPrepareData = async (ctx) => {
  const props: OrderCheckoutProps = {
    // ...
    isGiftPointPolicyActive: (ctx.is_gift_point_policy_enabled ?? false) && ctx.gift !== null,
  };
};
```

**`App.tsx`:**
```ts
export type OrderCheckoutProps = {
  // ...
  isGiftPointPolicyActive?: boolean; // 추가
};
```

**컴포넌트:** prop을 받아서 조건부 렌더링

### 레이어 4: Twig 템플릿

Islands 안은 React가 제어. 밖 HTML만 Twig에서 수정:
```twig
{% if islands['Ridipay'] %}
  {{ islands['Ridipay'] | raw }}
{% endif %}
```

## books-islands vs web/ridibooks 상세 비교

| 항목 | `books-islands` | `web/ridibooks` |
|------|-----------------|-----------------|
| **렌더링 대상** | PHP Twig 페이지 (레거시) | Next.js 페이지 (모던) |
| **SSR** | Node.js 서버, PHP에 주입 | Next.js 내장 SSR |
| **Ridipay** | 단일 900줄 모놀리식 컴포넌트 | Provider + Container + 추출된 훅으로 분리 |
| **상태 관리** | `reconstate` + 인라인 로직 | 같은 `reconstate`이나 훅이 `hooks/`로 추출됨 |
| **코드 공유** | 공유 없음 | books-islands 체크아웃 컴포넌트 import 없음 |

`ridibooks`는 `@ridi-web/books-islands`를 의존성으로 가지지만, 체크아웃 컴포넌트는 import하지 않는다. 같은 기능을 추가하면 **양쪽 모두 별도로 구현**해야 한다.
