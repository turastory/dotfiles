# RIDI Event System 상세 가이드

이 문서는 RIDI 백엔드의 event-driven 아키텍처에 대한 상세한 구현 가이드입니다.

## 목차

1. [아키텍처 개요](#아키텍처-개요)
2. [이벤트 정의하기](#이벤트-정의하기)
3. [이벤트 발행하기](#이벤트-발행하기)
4. [Subscriber 구현하기](#subscriber-구현하기)
5. [CRM 도구 연동](#crm-도구-연동)
6. [실전 예제: 새 이벤트 시스템 구축](#실전-예제-새-이벤트-시스템-구축)
7. [고급 패턴](#고급-패턴)

---

## 아키텍처 개요

### Event-Driven Architecture

RIDI 백엔드는 비동기 처리를 위해 Kafka 기반의 event-driven 아키텍처를 사용합니다.

```
┌─────────────┐         ┌─────────────┐         ┌──────────────────┐
│   API       │         │   Outbox    │         │     Kafka        │
│   Server    │────────▶│   Table     │────────▶│   (r-bus)        │
│             │  (1)    │   (Books)   │  (2)    │                  │
└─────────────┘         └─────────────┘         └──────────────────┘
                                                          │
                                                          │ (3)
                        ┌─────────────────────────────────┴─────────┐
                        │                                           │
                        ▼                                           ▼
              ┌───────────────────┐                    ┌──────────────────┐
              │   Amplitude       │                    │   Send Email     │
              │   Subscriber      │                    │   Subscriber     │
              │   (CRM Events)    │                    │                  │
              └───────────────────┘                    └──────────────────┘

(1) 트랜잭션 내에서 이벤트를 Outbox 테이블에 저장
(2) Outbox Publisher가 주기적으로 Outbox → Kafka 전송
(3) Subscriber들이 Kafka에서 이벤트를 소비하여 비동기 작업 수행
```

### 핵심 컴포넌트

1. **r-bus**: 이벤트 정의 및 pub/sub 인터페이스
2. **Outbox Pattern**: 트랜잭션과 이벤트 발행의 원자성 보장
3. **Subscribers**: 이벤트 소비자 (Worker)

---

## 이벤트 정의하기

### 1. 기본 구조

모든 이벤트는 `backends/src/r-bus/{eventName}` 디렉토리에 정의됩니다.

```
r-bus/cart/
├── config/
│   └── index.ts        # topic, type 설정
└── index.ts            # 메시지 타입, subscribe/publish 함수
```

### 2. Config 파일 작성

**파일**: `r-bus/cart/config/index.ts`

```typescript
import config from 'ridi-backends/utils/config';

export const load = () =>
  config(
    {
      topic: {
        default: 'cart',  // Kafka 토픽 이름
      },
      type: {
        default: 'com.ridi.cart',  // CloudEvents type (역방향 도메인)
      },
    },
    __dirname,
  );

export default load();
```

**핵심 개념**:
- `topic`: Kafka 토픽 이름 (kebab-case)
- `type`: CloudEvents 스펙의 type 필드 (역방향 도메인 네이밍)

### 3. 메시지 타입 정의

**파일**: `r-bus/cart/index.ts`

```typescript
import {
  createPublishToOutbox,
  createSubscribe,
} from 'ridi-backends/r-bus/utils';
import type { AttributionToolParams } from 'ridi-backends/types/attribution-tool-params';
import config from './config';

const { topic, type } = config;

// 1. 메시지 타입 정의
export type Message = {
  bookIds: string[];
  timestamp: number;
  type:
    | 'added-by-user'
    | 'moved-from-wishlist'
    | 'moved-to-wishlist'
    | 'removed-by-admin-book-provider'
    | 'removed-by-order-completed'
    | 'removed-by-user';
  userIdx: number;
  attributionToolParams?: AttributionToolParams;  // CRM 도구용 파라미터
};

// 2. Subscribe 함수 생성
export const subscribeCart = createSubscribe<Message>(topic);

// 3. Publish 함수 생성 (Outbox 패턴)
export const publishCartToOutbox = createPublishToOutbox<Message>({
  topic,
  type,
});
```

**타입 설계 원칙**:
- **불변성**: 발생한 사실을 기록 (과거형)
- **완전성**: Subscriber가 필요한 모든 데이터 포함
- **확장성**: 선택적 필드는 `?` 사용

### 4. Transform 함수 (선택사항)

Legacy 시스템과의 호환을 위해 메시지 변환이 필요한 경우:

```typescript
// PHP에서 bigint가 string으로 전달되는 경우 변환
export const subscribeOrderCompleted = createSubscribe<Message>(
  topic,
  (m) => typeof m.payId === 'string' ? { ...m, payId: Number(m.payId) } : m
);
```

### 5. Export 추가

**파일**: `r-bus/index.ts`

```typescript
export { publishCartToOutbox, subscribeCart } from './cart';
```

---

## 이벤트 발행하기

### 1. Outbox Pattern (권장)

트랜잭션 내에서 이벤트를 발행하여 DB 변경과 이벤트 발행의 원자성을 보장합니다.

**예시**: 카트에 도서 추가

**파일**: `backends/src/apps/api/routes/v2/cart/controller.ts`

```typescript
import { publishCartToOutbox } from 'ridi-backends/r-bus';
import { booksPrimary } from 'ridi-backends/db';
import { getAttributionToolParams, unixTimestamp } from 'ridi-backends/utils';

export const add: RequestHandler<unknown, AddResponseBody, AddRequestBody> = 
  async (req, res) => {
    const userIdx = req.user.idx;
    const { bookIds } = await getBookIds(...);
    
    await booksPrimary.transaction(async (trx) => {
      // 1. DB 작업 (카트에 도서 추가)
      await q.insertCartItems(userIdx, bookIds, trx);
      
      // 2. 이벤트 발행 (같은 트랜잭션 내)
      await publishCartToOutbox(
        [{
          bookIds,
          timestamp: unixTimestamp(),
          type: 'added-by-user',
          userIdx,
          attributionToolParams: getAttributionToolParams(req),
        }],
        trx,
        { req }  // source 추출용
      );
    });
    
    res.json({ result: { count: bookIds.length } });
  };
```

**핵심 포인트**:
1. `booksPrimary.transaction()`: DB 트랜잭션 시작
2. DB 작업 수행 (`.transacting(trx)` 필수)
3. `publishCartToOutbox`: 같은 트랜잭션 내에서 이벤트 저장
4. 트랜잭션 커밋 시 DB와 이벤트가 함께 반영됨

### 2. 주문 완료 이벤트 예시

**파일**: `backends/src/apps/books/utils/order/flow/completion/completeOrder.ts`

```typescript
import {
  publishOrderCompletedToOutbox,
  publishPayInfoToOutbox,
} from 'ridi-backends/r-bus';

export const completeOrder = async (
  order: Order,
  req: Request,
  trx: Knex.Transaction,
) => {
  // 1. 결제 정보 저장
  const payId = await insertPayInfo(order, trx);
  
  // 2. 도서 제공
  if (isContentsOrder(order)) {
    await providePurchasedBooks(order, trx);
  }
  
  // 3. PayInfo 이벤트 발행
  await publishPayInfoToOutbox(
    [{
      userIdx: order.userIdx,
      payId,
      timestamp: unixTimestamp(),
      type: 'create',
      attributionToolParams: getAttributionToolParams(req),
    }],
    trx,
    { req }
  );
  
  // 4. OrderCompleted 이벤트 발행
  await publishOrderCompletedToOutbox(
    [{
      userIdx: order.userIdx,
      payId,
      timestamp: unixTimestamp(),
    }],
    trx,
    { req }
  );
  
  return payId;
};
```

### 3. AttributionToolParams 전달

CRM 도구(Amplitude, Airbridge)에 필요한 파라미터를 이벤트에 포함:

```typescript
import { getAttributionToolParams } from 'ridi-backends/utils';

// Request에서 자동으로 추출
const attributionToolParams = getAttributionToolParams(req);

// 포함되는 정보:
// - amplitude: { device_id, session_id, environment }
// - airbridge: { cookie_id, short_id, channel, campaign_params }
// - android: { gaid, app_set_id }
// - ios: { idfa, idfv }
// - device_type, path
```

---

## Subscriber 구현하기

### 1. 기본 구조

```
subscribers/services/amplitude-event/
├── config/
│   └── index.ts        # groupId 설정
├── cart/
│   ├── index.ts        # consumer 생성
│   ├── cart.ts         # 핸들러 로직
│   ├── queries.ts      # DB 쿼리
│   └── config/
│       └── index.ts    # (선택) 추가 설정
├── purchase/
├── index.ts            # 모든 consumer export
└── utils.ts            # 공통 유틸
```

### 2. Config 작성

**파일**: `subscribers/services/amplitude-event/config/index.ts`

```typescript
import config from 'ridi-backends/utils/config';

export const load = () =>
  config(
    {
      groupId: {
        default: 'amplitude-event',  // Kafka consumer group ID
      },
    },
    __dirname,
  );

export default load();
```

**Consumer Group ID**:
- 각 subscriber마다 고유한 ID 사용
- 같은 이벤트를 여러 subscriber가 독립적으로 소비
- 예: `cart` 이벤트 → `amplitude-event`, `log-cart-history`

### 3. Handler 구현 (eachBatch 패턴)

**파일**: `subscribers/services/amplitude-event/cart/cart.ts`

```typescript
import * as _ from 'lodash';
import { subscribeCart } from 'ridi-backends/r-bus';
import { sendBatchEvent } from 'ridi-backends/subscribers/services/amplitude-event/utils';
import * as q from './queries';

const allowedTypes = new Set(['added-by-user', 'moved-from-wishlist']);

export default subscribeCart({
  eachBatch: async ({ messages }) => {
    // 1. 필터링 및 중복 제거
    const targetMessages = _.uniqBy(
      messages
        .filter((m) => allowedTypes.has(m.type))
        .map((m) => ({
          message: m,
          amplitudeEnvironment:
            m.attributionToolParams?.amplitude?.environment ??
            (process.env.NODE_ENV === 'production' ? 'prod' : 'dev'),
        })),
      ({ message, amplitudeEnvironment }) =>
        `${message.userIdx}-${amplitudeEnvironment}`,
    );
    
    // 2. DB에서 필요한 데이터 조회
    const lastAddedCartBooks = await q.findLastAddedCartBooks(
      _.uniq(targetMessages.map(({ message }) => message.userIdx)),
    );
    
    const bookIdToBookMap = _.keyBy(
      await q.findBooks(_.uniq(lastAddedCartBooks.map(({ bookId }) => bookId))),
      ({ id }) => id,
    );
    
    // 3. Amplitude 이벤트 생성 및 전송
    await sendBatchEvent(
      targetMessages
        .filter(({ message }) => {
          const lastAddedCartBook = userIdxToLastAddedCartBookMap[message.userIdx];
          return lastAddedCartBook && bookIdToBookMap[lastAddedCartBook.bookId];
        })
        .map(({ message, amplitudeEnvironment }) => {
          const book = bookIdToBookMap[
            userIdxToLastAddedCartBookMap[message.userIdx].bookId
          ];
          return {
            environment: amplitudeEnvironment,
            event: {
              userIdx: message.userIdx,
              eventType: '$identify',
              userProperties: {
                last_cart_item_id: book.id,
                last_cart_item_name: book.title,
                last_cart_item_genre: book.genre,
              },
            },
          };
        }),
    );
  },
});
```

**eachBatch 패턴의 장점**:
- 배치 단위로 DB 조회 최적화
- 메모리 효율적
- throughput 향상

### 4. Handler 구현 (eachMessage 패턴)

간단한 로직에 적합:

```typescript
export default subscribeCart({
  eachMessage: async (message, heartbeat) => {
    // 메시지별 처리
    await processMessage(message);
    
    // heartbeat 호출 (consumer 타임아웃 방지)
    await heartbeat();
  },
});
```

### 5. Consumer 생성

**파일**: `subscribers/services/amplitude-event/cart/index.ts`

```typescript
import { createConsumer } from 'ridi-backends/subscribers/utils';
import cart from './cart';
import config from './config';

export default () => createConsumer(config.groupId, [cart]);
```

### 6. 여러 이벤트 구독

하나의 consumer에서 여러 이벤트를 구독:

**파일**: `subscribers/services/amplitude-event/index.ts`

```typescript
import cart from './cart';
import purchase from './purchase';
import signUp from './signUp';

export default () => [
  cart(),
  purchase(),
  signUp(),
];
```

### 7. Heartbeat 사용

긴 작업 중 주기적으로 `heartbeat()` 호출:

```typescript
export default subscribePayInfo({
  eachBatch: async ({ heartbeat, messages }) => {
    for (const m of messages) {
      // 메시지 처리
      await processOrder(m);
      
      // 외부 API 호출 (시간 소요)
      await sendToExternalService(m);
      
      // heartbeat 호출 (타임아웃 방지)
      await heartbeat();
    }
  },
});
```

**Heartbeat의 역할**:
- Kafka에 consumer가 살아있음을 알림
- 타임아웃 방지
- Offset commit 트리거

---

## CRM 도구 연동

### Amplitude (사용자 행동 분석)

#### 공통 유틸리티

**파일**: `subscribers/services/amplitude-event/utils.ts`

```typescript
import _ from 'lodash';
import * as amplitude from 'ridi-backends/services/amplitude';

export const sendBatchEvent = async (
  events: {
    environment: 'dev' | 'prod';
    event: amplitude.Event;
  }[],
) => {
  // dev/prod 환경 분리
  const [prodEvents, devEvents] = _.partition(
    events,
    ({ environment }) => environment === 'prod',
  );
  
  await Promise.all([
    amplitude.sendBatchEvent('prod', [
      ...prodEvents.map(({ event }) => event),
      // stage에서 발생한 이벤트의 유저 속성은 prod에도 반영
      ...(process.env.NODE_ENV === 'production'
        ? devEvents
            .filter(({ event }) => event.userProperties)
            .map(({ event }) => ({
              userIdx: event.userIdx,
              eventType: '$identify',
              userProperties: event.userProperties,
            }))
        : []),
    ]),
    amplitude.sendBatchEvent(
      'dev',
      devEvents.map(({ event }) => event),
    ),
  ]);
};
```

#### Purchase 이벤트

**파일**: `subscribers/services/amplitude-event/purchase/payInfo.ts`

```typescript
import { subscribePayInfo } from 'ridi-backends/r-bus';
import type { Message } from 'ridi-backends/r-bus/payInfo';
import { sendBatchEvent } from '../utils';

export default subscribePayInfo({
  eachBatch: async ({ messages, heartbeat }) => {
    // 1. DB 조회
    const purchases = await q.findBookPurchases(
      messages.map((m) => Number(m.payId))
    );
    
    // 2. 이벤트 생성
    await sendBatchEvent(
      messages.flatMap((m) => {
        const purchase = payIdToPurchaseMap[m.payId];
        
        if (purchase.sum === 0) {
          // 무료 구매
          return [{
            environment: m.attributionToolParams?.amplitude?.environment ?? 'prod',
            event: {
              userIdx: purchase.userIdx,
              eventType: 'purchase_free',
              eventProperties: {
                items: purchaseItems,
                coupon_used: getCouponName(purchase.payType),
              },
            },
          }];
        } else {
          // 유료 구매: purchase + purchase_item 이벤트
          return [
            {
              environment: amplitudeEnvironment,
              event: {
                userIdx: purchase.userIdx,
                eventType: 'purchase',
                eventProperties: {
                  total_sum: purchase.sum,
                  purchase_type: '소장',
                },
                userProperties: {
                  last_ordered_date: formatKST(purchase.regDate),
                  total_order_count: summary.count,
                  total_order_amount: summary.amount,
                },
                revenue: purchase.sum,
                productId: purchase.transactionId,
              },
            },
            ...purchaseItems.map((item) => ({
              environment: amplitudeEnvironment,
              event: {
                userIdx: purchase.userIdx,
                eventType: 'purchase_item',
                eventProperties: { ...item },
              },
            })),
          ];
        }
      }),
    );
  },
});
```

**Amplitude 이벤트 타입**:
- `$identify`: 유저 속성 업데이트만
- 일반 이벤트: `eventType`에 이벤트 이름
- Revenue tracking: `revenue`, `productId` 필드 포함

### Airbridge (모바일 어트리뷰션)

**파일**: `subscribers/services/airbridge-event/order/payInfo.ts`

```typescript
import { subscribePayInfo } from 'ridi-backends/r-bus';
import type { Message } from 'ridi-backends/r-bus/payInfo';
import {
  StandardEvent,
  sendAppEvent,
  sendWebEvent,
} from 'ridi-backends/services/airbridge';
import { getPlatformInfo, Platform } from 'ridi-backends/utils';

export default subscribePayInfo({
  eachBatch: async ({ heartbeat, messages }) => {
    const purchases = await q.findBookPurchases(...);
    
    for (const m of messages) {
      const purchase = payIdToPurchaseMap[m.payId];
      
      // 1. 이벤트 객체 생성
      const event = {
        timestamp: parseKST(purchase.regDate, DateFormat.Compact),
        user: { externalUserID: purchase.userIdx.toString() },
        goal: {
          category: StandardEvent.ORDER_COMPLETE,
          value: purchase.sum,
          semanticAttributes: {
            currency: 'KRW',
            transactionID: purchase.transactionId,
            products: [...seriesProducts, ...singleBookProducts],
            contributionMargin: purchase.sum - pointSpentAmount,
          },
        },
      };
      
      // 2. 환경 결정
      const airbridgeEnvironment =
        m.attributionToolParams?.airbridge?.environment ??
        (process.env.NODE_ENV === 'production' ? 'prod' : 'dev');
      
      // 3. 플랫폼별 처리
      const { platform } = getPlatformInfo(userAgent);
      
      switch (platform) {
        case Platform.ANDROID:
        case Platform.ONEPUN:
          await sendAppEvent(airbridgeEnvironment, {
            ...event,
            client: {
              userAgent,
              ip,
              gaid: m.attributionToolParams?.android?.gaid,
              appSetID: m.attributionToolParams?.android?.app_set_id,
            },
          });
          break;
          
        case Platform.IOS:
          await sendAppEvent(airbridgeEnvironment, {
            ...event,
            client: {
              userAgent,
              ip,
              ifa: m.attributionToolParams?.ios?.idfa,
              ifv: m.attributionToolParams?.ios?.idfv,
            },
          });
          break;
          
        default:  // Web
          await sendWebEvent(airbridgeEnvironment, {
            ...event,
            client: {
              userAgent,
              ip,
              clientID: m.attributionToolParams?.airbridge?.cookie_id,
              shortID: m.attributionToolParams?.airbridge?.short_id,
              trackingChannel: m.attributionToolParams?.airbridge?.channel,
              trackingParams: m.attributionToolParams?.airbridge?.campaign_params,
            },
          });
      }
      
      await heartbeat();
    }
  },
  eachBatchSize: 20,  // 외부 API 호출이 많아 배치 크기 제한
});
```

**Airbridge 핵심**:
- 플랫폼별로 다른 식별자 사용 (GAID, IDFA, Cookie ID)
- App/Web 이벤트 API 분리
- `StandardEvent` 사용 (ORDER_COMPLETE, ORDER_CANCEL 등)

---

## 실전 예제: 새 이벤트 시스템 구축

### 시나리오

"리뷰 작성" 기능에 대한 이벤트 시스템을 구축합니다:
1. 사용자가 리뷰를 작성하면 `review` 이벤트 발행
2. Amplitude에 리뷰 작성 이벤트 전송
3. 리뷰 작성 이력을 별도 테이블에 로깅

### 1단계: 이벤트 정의

#### 1.1 Config 작성

```bash
mkdir -p backends/src/r-bus/review/config
```

**파일**: `backends/src/r-bus/review/config/index.ts`

```typescript
import config from 'ridi-backends/utils/config';

export const load = () =>
  config(
    {
      topic: {
        default: 'review',
      },
      type: {
        default: 'com.ridi.review',
      },
    },
    __dirname,
  );

export default load();
```

#### 1.2 메시지 타입 정의

**파일**: `backends/src/r-bus/review/index.ts`

```typescript
import {
  createPublishToOutbox,
  createSubscribe,
} from 'ridi-backends/r-bus/utils';
import type { AttributionToolParams } from 'ridi-backends/types/attribution-tool-params';
import config from './config';

const { topic, type } = config;

export type Message = {
  reviewId: number;
  bookId: string;
  userIdx: number;
  rating: number;
  content: string;
  timestamp: number;
  action: 'create' | 'update' | 'delete';
  attributionToolParams?: AttributionToolParams;
};

export const subscribeReview = createSubscribe<Message>(topic);

export const publishReviewToOutbox = createPublishToOutbox<Message>({
  topic,
  type,
});
```

#### 1.3 Export 추가

**파일**: `backends/src/r-bus/index.ts`

```typescript
// 기존 export들...
export { publishReviewToOutbox, subscribeReview } from './review';
```

### 2단계: API에서 이벤트 발행

**파일**: `backends/src/apps/books/routes/api/reviews/create.ts`

```typescript
import { publishReviewToOutbox } from 'ridi-backends/r-bus';
import { booksPrimary } from 'ridi-backends/db';
import { getAttributionToolParams, unixTimestamp } from 'ridi-backends/utils';

export const createReview: RequestHandler = async (req, res) => {
  const { bookId, rating, content } = req.body;
  const userIdx = req.user.idx;
  
  await booksPrimary.transaction(async (trx) => {
    // 1. 리뷰 저장
    const [reviewId] = await trx('review')
      .insert({
        book_id: bookId,
        user_idx: userIdx,
        rating,
        content,
        created_at: new Date(),
      })
      .returning('id');
    
    // 2. 리뷰 이벤트 발행
    await publishReviewToOutbox(
      [{
        reviewId,
        bookId,
        userIdx,
        rating,
        content,
        timestamp: unixTimestamp(),
        action: 'create',
        attributionToolParams: getAttributionToolParams(req),
      }],
      trx,
      { req }
    );
  });
  
  res.json({ success: true });
};
```

### 3단계: Amplitude Subscriber 구현

#### 3.1 디렉토리 생성

```bash
mkdir -p backends/src/subscribers/services/amplitude-event/review/config
```

#### 3.2 Config

**파일**: `backends/src/subscribers/services/amplitude-event/review/config/index.ts`

```typescript
import config from 'ridi-backends/utils/config';

export default config({}, __dirname);
```

#### 3.3 Queries

**파일**: `backends/src/subscribers/services/amplitude-event/review/queries.ts`

```typescript
import { booksPrimary } from 'ridi-backends/db';

export const findBooks = (bookIds: string[]) =>
  booksPrimary('book')
    .select('id', 'title', 'genre', 'category')
    .whereIn('id', bookIds);
```

#### 3.4 Handler

**파일**: `backends/src/subscribers/services/amplitude-event/review/review.ts`

```typescript
import * as _ from 'lodash';
import { subscribeReview } from 'ridi-backends/r-bus';
import { sendBatchEvent } from 'ridi-backends/subscribers/services/amplitude-event/utils';
import * as q from './queries';

export default subscribeReview({
  eachBatch: async ({ messages }) => {
    // create 액션만 처리
    const createMessages = messages.filter((m) => m.action === 'create');
    
    if (createMessages.length === 0) {
      return;
    }
    
    // 도서 정보 조회
    const bookIdToBookMap = _.keyBy(
      await q.findBooks(_.uniq(createMessages.map((m) => m.bookId))),
      ({ id }) => id,
    );
    
    // Amplitude 이벤트 전송
    await sendBatchEvent(
      createMessages.map((m) => {
        const book = bookIdToBookMap[m.bookId];
        const amplitudeEnvironment =
          m.attributionToolParams?.amplitude?.environment ??
          (process.env.NODE_ENV === 'production' ? 'prod' : 'dev');
        
        return {
          environment: amplitudeEnvironment,
          event: {
            userIdx: m.userIdx,
            eventType: 'review_create',
            eventProperties: {
              review_id: m.reviewId,
              book_id: m.bookId,
              book_title: book?.title,
              book_genre: book?.genre,
              rating: m.rating,
              content_length: m.content.length,
            },
            userProperties: {
              last_review_date: new Date(m.timestamp * 1000).toISOString().split('T')[0],
              last_reviewed_book_id: m.bookId,
              last_reviewed_book_genre: book?.genre,
            },
          },
        };
      }),
    );
  },
});
```

#### 3.5 Consumer 생성

**파일**: `backends/src/subscribers/services/amplitude-event/review/index.ts`

```typescript
import { createConsumer } from 'ridi-backends/subscribers/utils';
import review from './review';
import config from './config';

export default () => createConsumer('amplitude-event-review', [review]);
```

#### 3.6 Services Index에 추가

**파일**: `backends/src/subscribers/services/amplitude-event/index.ts`

```typescript
import review from './review';
// ... 기존 import들

export default () => [
  // ... 기존 consumer들
  review(),
];
```

### 4단계: 로깅 Subscriber 구현

#### 4.1 디렉토리 생성

```bash
mkdir -p backends/src/subscribers/services/log-review-history/config
```

#### 4.2 Config

**파일**: `backends/src/subscribers/services/log-review-history/config/index.ts`

```typescript
import config from 'ridi-backends/utils/config';

export const load = () =>
  config(
    {
      groupId: {
        default: 'log-review-history',
      },
    },
    __dirname,
  );

export default load();
```

#### 4.3 Queries

**파일**: `backends/src/subscribers/services/log-review-history/queries.ts`

```typescript
import { libraryPrimary } from 'ridi-backends/db';

export const insertReviewHistory = (
  records: Array<{
    review_id: number;
    book_id: string;
    user_idx: number;
    action: string;
    timestamp: Date;
  }>
) =>
  libraryPrimary('review_history').insert(records);
```

#### 4.4 Handler

**파일**: `backends/src/subscribers/services/log-review-history/review.ts`

```typescript
import { subscribeReview } from 'ridi-backends/r-bus';
import * as q from './queries';

export default subscribeReview({
  eachBatch: async ({ messages }) => {
    // 모든 액션을 이력에 기록
    await q.insertReviewHistory(
      messages.map((m) => ({
        review_id: m.reviewId,
        book_id: m.bookId,
        user_idx: m.userIdx,
        action: m.action,
        timestamp: new Date(m.timestamp * 1000),
      }))
    );
  },
});
```

#### 4.5 Consumer 생성

**파일**: `backends/src/subscribers/services/log-review-history/index.ts`

```typescript
import { createConsumer } from 'ridi-backends/subscribers/utils';
import review from './review';
import config from './config';

export default () => createConsumer(config.groupId, [review]);
```

### 5단계: 테스트

#### 5.1 Config 테스트

**파일**: `backends/src/r-bus/review/config/config.test.ts`

```typescript
import { load } from '.';

describe('review config', () => {
  it('should load config', () => {
    const config = load();
    expect(config.topic).toBe('review');
    expect(config.type).toBe('com.ridi.review');
  });
});
```

#### 5.2 Handler 테스트

**파일**: `backends/src/subscribers/services/amplitude-event/review/review.test.ts`

```typescript
import { subscribeReview } from 'ridi-backends/r-bus';
import * as amplitude from 'ridi-backends/services/amplitude';
import handler from './review';

jest.mock('ridi-backends/services/amplitude');

describe('amplitude-event review handler', () => {
  it('should send amplitude event for create action', async () => {
    const messages = [
      {
        reviewId: 1,
        bookId: 'book123',
        userIdx: 100,
        rating: 5,
        content: 'Great book!',
        timestamp: 1234567890,
        action: 'create' as const,
      },
    ];
    
    await handler.handler.eachBatch!({
      messages,
      heartbeat: jest.fn(),
    });
    
    expect(amplitude.sendBatchEvent).toHaveBeenCalled();
  });
  
  it('should skip non-create actions', async () => {
    const messages = [
      {
        reviewId: 1,
        bookId: 'book123',
        userIdx: 100,
        rating: 5,
        content: 'Updated',
        timestamp: 1234567890,
        action: 'update' as const,
      },
    ];
    
    await handler.handler.eachBatch!({
      messages,
      heartbeat: jest.fn(),
    });
    
    expect(amplitude.sendBatchEvent).not.toHaveBeenCalled();
  });
});
```

---

## 고급 패턴

### 1. 멱등성 보장

동일한 메시지를 여러 번 받아도 결과가 동일하도록:

```typescript
export default subscribePayInfo({
  eachBatch: async ({ messages }) => {
    for (const m of messages) {
      // 1. 이미 처리된 메시지인지 확인
      const existing = await q.findProcessedMessage(m.payId);
      if (existing) {
        continue;  // 이미 처리됨
      }
      
      // 2. 처리
      await processPayment(m);
      
      // 3. 처리 완료 기록
      await q.insertProcessedMessage(m.payId);
    }
  },
});
```

### 2. Dead Letter Queue 패턴

실패한 메시지를 별도로 저장:

```typescript
export default subscribeOrder({
  eachBatch: async ({ messages }) => {
    for (const m of messages) {
      try {
        await processOrder(m);
      } catch (error) {
        // 실패 로깅
        await q.insertFailedMessage({
          message: JSON.stringify(m),
          error: error.message,
          timestamp: new Date(),
        });
        
        // 에러 리포팅
        errorHandler(error);
        
        // 다음 메시지 계속 처리
      }
    }
  },
});
```

### 3. 배치 크기 최적화

외부 API 호출이 많은 경우 배치 크기를 줄임:

```typescript
export default subscribePayInfo({
  eachBatch: async ({ heartbeat, messages }) => {
    // 배치당 20개씩만 처리
    for (const m of messages) {
      await sendToExternalAPI(m);
      await heartbeat();
    }
  },
  eachBatchSize: 20,  // 기본값: 1000
});
```

### 4. 여러 토픽 구독

하나의 consumer에서 여러 이벤트 처리:

```typescript
export default () =>
  createConsumer('process-orders', [
    {
      topic: 'order-completed',
      handler: {
        eachBatch: async ({ messages }) => {
          await handleCompleted(messages);
        },
      },
    },
    {
      topic: 'order-cancelled',
      handler: {
        eachBatch: async ({ messages }) => {
          await handleCancelled(messages);
        },
      },
    },
  ]);
```

### 5. Transform 활용

메시지 변환 로직 분리:

```typescript
// Transform 함수 정의
const transformMessage = (m: RawMessage): Message => {
  return {
    ...m,
    payId: Number(m.payId),  // string → number
    timestamp: m.timestamp / 1000,  // ms → seconds
  };
};

// Subscribe 시 적용
export const subscribeOrder = createSubscribe<Message>(
  topic,
  transformMessage
);
```

### 6. Validator 사용

메시지 검증 추가:

```typescript
import Ajv from 'ajv';

const ajv = new Ajv();
const schema = {
  type: 'object',
  properties: {
    userIdx: { type: 'number' },
    bookId: { type: 'string' },
  },
  required: ['userIdx', 'bookId'],
};

const validator = ajv.compile(schema);

export const subscribeCart = createSubscribeWithOption<Message>(
  topic,
  { validator }
);
```

---

## 코드 참조

### 이벤트 정의

- **Cart**: [`backends/src/r-bus/cart/index.ts`](https://github.com/ridi/ridi/blob/master/backends/src/r-bus/cart/index.ts:1-30)
  ```typescript
  export type Message = {
    bookIds: string[];
    timestamp: number;
    type: 'added-by-user' | 'removed-by-user' | ...;
    userIdx: number;
  };
  ```

- **OrderCompleted**: [`backends/src/r-bus/orderCompleted/index.ts`](https://github.com/ridi/ridi/blob/master/backends/src/r-bus/orderCompleted/index.ts:1-24)
  ```typescript
  interface Message {
    userIdx: number;
    payId: number;
    timestamp: number;
  }
  ```

- **PayInfo**: [`backends/src/r-bus/payInfo/index.ts`](https://github.com/ridi/ridi/blob/master/backends/src/r-bus/payInfo/index.ts)

### API에서 이벤트 발행

- **Cart 추가**: [`backends/src/apps/api/routes/v2/cart/controller.ts`](https://github.com/ridi/ridi/blob/master/backends/src/apps/api/routes/v2/cart/controller.ts:200-236)
  ```typescript
  await booksPrimary.transaction(async (trx) => {
    await insertCartItems(bookIds, trx);
    await publishCartToOutbox([{ ... }], trx, { req });
  });
  ```

- **주문 완료**: [`backends/src/apps/books/utils/order/flow/completion/completeOrder.ts`](https://github.com/ridi/ridi/blob/master/backends/src/apps/books/utils/order/flow/completion/completeOrder.ts:147-465)
  ```typescript
  await publishPayInfoToOutbox([{ ... }], trx, { req });
  await publishOrderCompletedToOutbox([{ ... }], trx, { req });
  ```

### Subscriber 구현

- **Amplitude Cart**: [`backends/src/subscribers/services/amplitude-event/cart/cart.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/services/amplitude-event/cart/cart.ts:10-87)
  ```typescript
  export default subscribeCart({
    eachBatch: async ({ messages }) => {
      const books = await findBooks(...);
      await sendBatchEvent([...]);
    },
  });
  ```

- **Amplitude Purchase**: [`backends/src/subscribers/services/amplitude-event/purchase/payInfo.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/services/amplitude-event/purchase/payInfo.ts:66-417)
  ```typescript
  export default subscribePayInfo({
    eachBatch: async ({ messages, heartbeat }) => {
      await handleCompletedOrders(messages, heartbeat);
      await handleCanceledOrders(messages, heartbeat);
    },
  });
  ```

- **Airbridge Order**: [`backends/src/subscribers/services/airbridge-event/order/payInfo.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/services/airbridge-event/order/payInfo.ts:41-216)
  ```typescript
  for (const m of messages) {
    switch (platform) {
      case Platform.ANDROID:
        await sendAppEvent(env, { client: { gaid, appSetID } });
        break;
      case Platform.IOS:
        await sendAppEvent(env, { client: { ifa, ifv } });
        break;
      default:
        await sendWebEvent(env, { client: { clientID } });
    }
  }
  ```

- **Cart History**: [`backends/src/subscribers/services/log-cart-history/cart.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/services/log-cart-history/cart.ts)

### 유틸리티

- **r-bus utils**: [`backends/src/r-bus/utils.ts`](https://github.com/ridi/ridi/blob/master/backends/src/r-bus/utils.ts:13-135)
  ```typescript
  export const createPublishToOutbox = <T>(...) => async (...) => { ... };
  export const createSubscribe = <T>(...) => (handler) => ({ ... });
  ```

- **subscriber utils**: [`backends/src/subscribers/utils.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/utils.ts:151-351)
  ```typescript
  export const createConsumer = async <T>(...) => { ... };
  export const runSubscriber = async (...) => { ... };
  ```

- **Amplitude utils**: [`backends/src/subscribers/services/amplitude-event/utils.ts`](https://github.com/ridi/ridi/blob/master/backends/src/subscribers/services/amplitude-event/utils.ts:48-80)
  ```typescript
  export const sendBatchEvent = async (events) => { ... };
  ```

---

## Backfill: 과거 데이터 처리

새로운 subscriber나 기능 추가 후 과거 데이터를 처리해야 할 때 backfill을 사용합니다.

### 언제 Backfill이 필요한가?

#### 시나리오 1: 새 Subscriber 추가

기존 `payInfo` 이벤트를 구독하는 새 subscriber를 추가했지만, 과거 결제 데이터도 처리해야 하는 경우:

```typescript
// 새로 추가한 subscriber
export default subscribePayInfo({
  eachBatch: async ({ messages }) => {
    // 새로운 통계 생성
    await createNewStatistics(messages);
  },
});

// ❌ 문제: 과거 데이터는 처리되지 않음
// ✅ 해결: Backfill 스크립트 작성
```

#### 시나리오 2: CRM 유저 속성 업데이트

Amplitude에 새로운 유저 속성을 추가했지만, 기존 유저들의 값이 비어있는 경우:

```typescript
// 새 subscriber: 실시간 업데이트
export default subscribeCart({
  eachBatch: async ({ messages }) => {
    await sendBatchEvent(messages.map(m => ({
      userIdx: m.userIdx,
      eventType: '$identify',
      userProperties: {
        last_cart_item_id: m.bookId,  // 새 속성
      },
    })));
  },
});

// ✅ Backfill: 모든 기존 유저의 last_cart_item_id 설정
```

### Backfill 스크립트 작성

#### 1. 파일 생성

```bash
# 위치: backends/src/batch/cmds/one-off-cmds/
touch backfill-{feature-name}.ts
```

#### 2. 기본 구조

```typescript
// backfill-new-statistics.ts
import delay from 'delay';
import pLimit from 'p-limit';
import type { CommandBuilder } from 'yargs';
import { pino } from 'ridi-backends/utils';

export const command = 'backfill-new-statistics <startPayId> <endPayId>';
export const desc = 'Backfill new statistics from payInfo';

export const builder: CommandBuilder = (yargs) =>
  yargs
    .positional('startPayId', {
      demandOption: true,
      type: 'number',
      description: '시작 결제 ID',
    })
    .positional('endPayId', {
      demandOption: true,
      type: 'number',
      description: '끝 결제 ID',
    })
    .option('dryRun', {
      default: true,
      type: 'boolean',
      description: '실제 저장하지 않고 테스트',
    })
    .option('chunkSize', {
      default: 10000,
      type: 'number',
      description: '한 번에 처리할 레코드 수',
    })
    .option('delay', {
      default: 0,
      type: 'number',
      description: '청크 사이 대기 시간 (ms)',
    });

// Retry 로직
export const retry = async <T>(
  run: () => Promise<T>,
  retries = 3,
): Promise<T> => {
  for (let i = 1; ; i += 1) {
    try {
      return await run();
    } catch (err) {
      if (i >= retries) throw err;
      pino.warn(`Retry ${i}/${retries}`, err);
    }
  }
};

export const handler = async (args: {
  startPayId: number;
  endPayId: number;
  dryRun: boolean;
  chunkSize: number;
  delay: number;
}) => {
  const { startPayId, endPayId, chunkSize } = args;
  
  // 청크 단위로 처리
  for (
    let windowStart = startPayId;
    windowStart <= endPayId;
    windowStart += chunkSize
  ) {
    const windowEnd = Math.min(windowStart + chunkSize, endPayId + 1);
    
    pino.info(
      `[backfill-new-statistics] Processing: ${windowStart} <= id < ${windowEnd}`
    );
    
    // 1. 데이터 조회 (retry 포함)
    const payments = await retry(() =>
      queries.findPayments(windowStart, windowEnd)
    );
    
    if (!payments.length) {
      pino.info('No data found, skipping...');
      continue;
    }
    
    // 2. 통계 생성
    const statistics = await processPayments(payments);
    
    // 3. 저장 (dryRun이 아닐 때만)
    if (args.dryRun) {
      pino.info(`[DRY RUN] Would insert ${statistics.length} records`);
    } else {
      await retry(() => queries.insertStatistics(statistics));
      pino.info(`Inserted ${statistics.length} records`);
    }
    
    // 4. 딜레이 (DB 부하 방지)
    if (args.delay > 0) {
      await delay(args.delay);
    }
  }
  
  pino.info('[backfill-new-statistics] Complete!');
};
```

#### 3. Queries 작성

```typescript
// backfill-new-statistics.ts (계속)
export const queries = {
  findPayments: (startId: number, endId: number) =>
    ridiReplicaForCms('bom', 'tb_pay_info')
      .select({
        id: 'id',
        userIdx: 'u_idx',
        sum: 'sum',
        regDate: 'reg_date',
      })
      .where('id', '>=', startId)
      .where('id', '<', endId)
      .where('sum', '>', 0)
      .where('cancel', 'N'),
      
  insertStatistics: (statistics: Array<{ payId: number; value: number }>) =>
    libraryPrimary('summary', 'new_statistics')
      .insert(
        statistics.map(({ payId, value }) => ({
          pay_id: payId,
          value: value,
        }))
      )
      .onConflict()
      .ignore(),  // 중복 방지
};

const processPayments = async (payments: Array<{ id: number; sum: number }>) => {
  // 비즈니스 로직
  return payments.map(p => ({
    payId: p.id,
    value: p.sum * 0.1,  // 예: 10% 수수료
  }));
};
```

### 실전 예시: Amplitude 유저 속성 Backfill

**시나리오**: 모든 유저의 `last_cart_item_id`, `total_order_count` 등을 Amplitude에 업데이트

**파일**: `backends/src/batch/cmds/one-off-cmds/backfillAmplitudeUserProperty/backfillUserProperties.ts`

```typescript
export const backfillUserProperties = async (
  users: Array<{
    idx: number;
    status: string;
    adultVerifiedAt: string | null;
    regDate: string;
  }>,
  dryRun: boolean,
) => {
  const userIdxs = users.map(u => u.idx);
  
  // 1. 모든 필요한 데이터를 병렬로 조회
  const [
    buildSignupDate,
    buildTotalOrder,
    buildLastCart,
    buildTotalCashCharge,
    buildMarketingOptIn,
  ] = await Promise.all([
    retry(() => createBuildSignupDateProperties(users)),
    retry(() => createBuildTotalOrderProperties(userIdxs)),
    retry(() => createBuildLastCartItemProperties(userIdxs)),
    retry(() => createBuildTotalCashChargeProperties(userIdxs)),
    retry(() => createBuildMarketingAgreementProperties(userIdxs)),
  ]);
  
  // 2. Amplitude 이벤트 생성
  const amplitudeEvents = users.map(user => ({
    userIdx: user.idx,
    eventType: '$identify',
    userProperties: {
      // $setOnce: 기존 값이 있으면 덮어쓰지 않음
      $setOnce: {
        signup_date: buildSignupDate(user.idx).signup_date,
        total_order_count: buildTotalOrder(user.idx).total_order_count,
        total_order_amount: buildTotalOrder(user.idx).total_order_amount,
        last_cart_item_id: buildLastCart(user.idx).last_cart_item_id,
        total_cash_charged_amount: buildTotalCashCharge(user.idx).total_cash_charged_amount,
        email_marketing_opt_in: buildMarketingOptIn(user.idx).email_marketing_opt_in,
      },
    },
  }));
  
  // 3. Amplitude 전송
  if (!dryRun) {
    await retry(() =>
      sendBatchEvent(
        process.env.NODE_ENV === 'production' ? 'prod' : 'dev',
        amplitudeEvents,
      )
    );
  }
};
```

**Helper 함수 예시**:

```typescript
// 유저별 총 주문 통계 조회
export const createBuildTotalOrderProperties = async (userIdxs: number[]) => {
  const bookPurchaseSummaries = await limit(() =>
    q.findBookPurchaseSummaries(userIdxs)
  );
  
  const userIdxToSummaryMap = _.keyBy(
    bookPurchaseSummaries,
    ({ userIdx }) => userIdx,
  );
  
  return (userIdx: number) => ({
    total_order_count: userIdxToSummaryMap[userIdx]?.count ?? 0,
    total_order_amount: userIdxToSummaryMap[userIdx]?.amount ?? 0,
  });
};

// 마지막 장바구니 항목 조회
export const createBuildLastCartItemProperties = async (userIdxs: number[]) => {
  const lastAddedCartBooks = await limit(() =>
    q.findLastAddedCartBooks(userIdxs)
  );
  
  const userIdxToLastCartMap = _.keyBy(
    lastAddedCartBooks,
    ({ userIdx }) => userIdx,
  );
  
  return (userIdx: number) => {
    const lastCart = userIdxToLastCartMap[userIdx];
    return {
      last_cart_item_id: lastCart?.bookId,
      last_cart_item_name: lastCart?.title,
      last_cart_item_genre: lastCart?.genre,
    };
  };
};
```

### Backfill 실행

#### 방법 1: Airflow (프로덕션 권장)

1. Airflow 웹 UI 접속
2. `backends-batch-cli` DAG 찾기
3. **Trigger DAG w/ config** 클릭
4. Configuration JSON 입력:

```json
{
  "command": [
    "one-off-cmds",
    "backfill-new-statistics",
    "1",
    "1000000",
    "--dryRun=false",
    "--chunkSize=10000",
    "--delay=1000"
  ]
}
```

#### 방법 2: 로컬 실행 (개발/테스트)

```bash
# 1. Dry run으로 테스트
yarn batch one-off-cmds backfill-new-statistics 1 10000 \
  --dryRun=true \
  --chunkSize=1000

# 2. 작은 범위로 실제 실행
yarn batch one-off-cmds backfill-new-statistics 1 1000 \
  --dryRun=false \
  --chunkSize=100 \
  --delay=500

# 3. 전체 실행
yarn batch one-off-cmds backfill-new-statistics 1 1000000 \
  --dryRun=false \
  --chunkSize=10000 \
  --delay=1000
```

### 핵심 패턴

#### 1. Concurrency 제어

```typescript
import pLimit from 'p-limit';

const readLimit = pLimit(6);   // 동시 읽기 6개
const writeLimit = pLimit(6);  // 동시 쓰기 6개

await Promise.all(
  _.chunk(purchases, 1000).map(chunkedPurchases =>
    retry(async () => {
      // 읽기
      const [userBooks, giftBooks] = await Promise.all([
        readLimit(() => queries.findUserBooks(payIds)),
        readLimit(() => queries.findGiftBooks(payIds)),
      ]);
      
      // 쓰기
      await Promise.all(
        _.chunk(summaries, 1000).map(chunk =>
          writeLimit(() => queries.insertSummaries(chunk))
        )
      );
    })
  )
);
```

#### 2. 트랜잭션 사용

관련 테이블을 함께 업데이트할 때:

```typescript
await booksPrimary.transaction(async (trx) => {
  // 여러 테이블 업데이트
  await queries.updateTable1(records, trx);
  await queries.updateTable2(records, trx);
  await queries.updateTable3(records, trx);
  
  // 모두 성공하거나 모두 롤백
});
```

#### 3. 멱등성 보장

같은 backfill을 여러 번 실행해도 안전하게:

```typescript
// 방법 1: onConflict().ignore()
await db('table')
  .insert(records)
  .onConflict('id')
  .ignore();

// 방법 2: onConflict().merge()
await db('table')
  .insert(records)
  .onConflict('id')
  .merge(['updated_at', 'value']);

// 방법 3: 존재 여부 확인
const existing = await db('table').whereIn('id', ids);
const newRecords = records.filter(r => !existing.includes(r.id));
await db('table').insert(newRecords);
```

### Best Practices

#### ✅ DO

1. **항상 Dry Run으로 시작**
   ```typescript
   if (dryRun) {
     pino.info(`[DRY RUN] Would process ${records.length} records`);
     return;
   }
   ```

2. **청크 단위로 처리**
   ```typescript
   const CHUNK_SIZE = 10000;  // 메모리 효율적
   for (let i = start; i < end; i += CHUNK_SIZE) { ... }
   ```

3. **상세한 로깅**
   ```typescript
   pino.info(`[backfill] Processing: ${start} ~ ${end}`);
   pino.info(`[backfill] Found ${records.length} records`);
   pino.info(`[backfill] Inserted ${inserted} records`);
   ```

4. **Retry 로직**
   ```typescript
   const data = await retry(() => fetchData(start, end), 3);
   ```

5. **진행률 표시**
   ```typescript
   const total = endId - startId;
   const progress = ((current - startId) / total * 100).toFixed(2);
   pino.info(`Progress: ${progress}% (${current}/${endId})`);
   ```

6. **딜레이 추가**
   ```typescript
   if (args.delay > 0) {
     await delay(args.delay);  // DB 부하 감소
   }
   ```

#### ❌ DON'T

1. **전체 데이터를 메모리에 로드**
   ```typescript
   // Bad
   const allData = await db('table').select();
   
   // Good
   for (let i = 0; i < total; i += CHUNK_SIZE) {
     const chunk = await db('table').limit(CHUNK_SIZE).offset(i);
   }
   ```

2. **에러 무시**
   ```typescript
   // Bad
   try {
     await process();
   } catch {
     // 무시
   }
   
   // Good
   try {
     await process();
   } catch (error) {
     pino.error('Processing failed', error);
     throw error;
   }
   ```

3. **중복 처리 미방지**
   ```typescript
   // Bad
   await db('table').insert(records);  // 중복 키 에러
   
   // Good
   await db('table').insert(records).onConflict().ignore();
   ```

### Troubleshooting

#### 문제 1: 메모리 부족

**증상**: "JavaScript heap out of memory"

**해결**:
```typescript
// chunkSize를 줄이기
--chunkSize=5000  // 기본값 10000에서 줄임

// Node.js 메모리 증가
NODE_OPTIONS=--max-old-space-size=4096 yarn batch ...
```

#### 문제 2: DB 타임아웃

**증상**: "Lock wait timeout exceeded"

**해결**:
```typescript
// 딜레이 추가
--delay=2000  // 각 청크 사이 2초 대기

// 동시성 제한
const limit = pLimit(3);  // 6에서 3으로 줄임
```

#### 문제 3: 중복 키 에러

**증상**: "Duplicate entry for key 'PRIMARY'"

**해결**:
```typescript
// 멱등성 보장
await db('table')
  .insert(records)
  .onConflict('id')
  .ignore();  // 또는 .merge()
```

#### 문제 4: 데이터 불일치

**증상**: 일부 테이블만 업데이트됨

**해결**:
```typescript
// 트랜잭션 사용
await db.transaction(async (trx) => {
  await updateTable1(trx);
  await updateTable2(trx);
});
```

## 요약

이 가이드를 통해 다음을 수행할 수 있습니다:

1. **새 이벤트 정의**: r-bus에 이벤트 타입과 pub/sub 함수 생성
2. **API에서 이벤트 발행**: Outbox 패턴으로 트랜잭션 내 이벤트 발행
3. **Subscriber 구현**: eachBatch/eachMessage 패턴으로 이벤트 소비
4. **CRM 연동**: Amplitude, Airbridge 등 외부 서비스 연동
5. **Backfill 작성**: 과거 데이터 처리 스크립트 작성 및 실행
6. **테스트 작성**: Config, Handler, Queries 단위 테스트

핵심은 **Outbox 패턴**으로 트랜잭션 안정성을 보장하고, **독립적인 Consumer Group**으로 확장 가능한 아키텍처를 구축하며, **Backfill**로 과거 데이터를 안전하게 처리하는 것입니다.
