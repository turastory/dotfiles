# RIDI Event System 빠른 참조

## 새 이벤트 추가 체크리스트

### 1. r-bus 이벤트 정의

```bash
# 디렉토리 생성
mkdir -p backends/src/r-bus/{eventName}/config
```

```typescript
// backends/src/r-bus/{eventName}/config/index.ts
export default config({
  topic: { default: 'event-name' },
  type: { default: 'com.ridi.event-name' },
}, __dirname);
```

```typescript
// backends/src/r-bus/{eventName}/index.ts
import { createPublishToOutbox, createSubscribe } from 'ridi-backends/r-bus/utils';

export type Message = {
  // 메시지 필드 정의
};

export const subscribeEventName = createSubscribe<Message>(topic);
export const publishEventNameToOutbox = createPublishToOutbox<Message>({ topic, type });
```

```typescript
// backends/src/r-bus/index.ts에 추가
export { publishEventNameToOutbox, subscribeEventName } from './eventName';
```

### 2. API에서 이벤트 발행

```typescript
import { publishEventNameToOutbox } from 'ridi-backends/r-bus';
import { booksPrimary } from 'ridi-backends/db';
import { getAttributionToolParams, unixTimestamp } from 'ridi-backends/utils';

await booksPrimary.transaction(async (trx) => {
  // DB 작업
  await updateDatabase(data, trx);
  
  // 이벤트 발행
  await publishEventNameToOutbox(
    [{ /* 메시지 데이터 */ }],
    trx,
    { req }
  );
});
```

### 3. Subscriber 생성

```bash
# 디렉토리 생성
mkdir -p backends/src/subscribers/services/{service-name}/config
```

```typescript
// config/index.ts
export default config({
  groupId: { default: 'service-name' },
}, __dirname);
```

```typescript
// handler.ts
import { subscribeEventName } from 'ridi-backends/r-bus';

export default subscribeEventName({
  eachBatch: async ({ messages, heartbeat }) => {
    // 처리 로직
    await processMessages(messages);
    await heartbeat();
  },
});
```

```typescript
// index.ts
import { createConsumer } from 'ridi-backends/subscribers/utils';
import handler from './handler';
import config from './config';

export default () => createConsumer(config.groupId, [handler]);
```

## 주요 함수 시그니처

### createPublishToOutbox

```typescript
createPublishToOutbox<T>(metadata: {
  topic: string;
  type: string;
  transform?: (message: T) => T | T[];
  key?: (message: T) => string;
}) => (
  messages: T[],
  trx: Knex.Transaction,
  opts: { req: Request } | { source: string }
) => Promise<void>
```

### createSubscribe

```typescript
createSubscribe<T>(
  topic: string,
  transform?: (message: T) => T
) => (handler: Handler<T>) => SubscriptionConfig
```

### Handler 타입

```typescript
interface Handler<T> {
  eachBatchSize?: number;
  eachBatch?: (payload: {
    messages: T[];
    heartbeat(): Promise<void>;
  }) => Promise<unknown>;
  eachMessage?: (
    message: T,
    heartbeat: () => Promise<void>
  ) => Promise<unknown>;
}
```

### createConsumer

```typescript
createConsumer<T>(
  groupId: string,
  handlers: Array<{
    topic: string;
    handler: Handler<any>;
    fromBeginning?: boolean;
    transform?: (m: any) => any;
    validator?: ValidateFunction<T>;
  }>,
  partitionsConsumedConcurrently?: number
) => Promise<Consumer>
```

## 코드 스니펫

### Amplitude 이벤트 전송

```typescript
import { sendBatchEvent } from 'ridi-backends/subscribers/services/amplitude-event/utils';

await sendBatchEvent(
  messages.map((m) => ({
    environment: m.attributionToolParams?.amplitude?.environment ?? 'prod',
    event: {
      userIdx: m.userIdx,
      eventType: 'custom_event',
      eventProperties: { /* ... */ },
      userProperties: { /* ... */ },
    },
  }))
);
```

### Airbridge 이벤트 전송

```typescript
import { sendAppEvent, sendWebEvent } from 'ridi-backends/services/airbridge';
import { getPlatformInfo, Platform } from 'ridi-backends/utils';

const { platform } = getPlatformInfo(userAgent);
const airbridgeEnv = m.attributionToolParams?.airbridge?.environment ?? 'prod';

const event = {
  timestamp: parseKST(date),
  user: { externalUserID: userIdx.toString() },
  goal: {
    category: StandardEvent.ORDER_COMPLETE,
    value: amount,
    semanticAttributes: { /* ... */ },
  },
};

switch (platform) {
  case Platform.ANDROID:
    await sendAppEvent(airbridgeEnv, {
      ...event,
      client: {
        gaid: m.attributionToolParams?.android?.gaid,
        appSetID: m.attributionToolParams?.android?.app_set_id,
      },
    });
    break;
  case Platform.IOS:
    await sendAppEvent(airbridgeEnv, {
      ...event,
      client: {
        ifa: m.attributionToolParams?.ios?.idfa,
        ifv: m.attributionToolParams?.ios?.idfv,
      },
    });
    break;
  default:
    await sendWebEvent(airbridgeEnv, {
      ...event,
      client: {
        clientID: m.attributionToolParams?.airbridge?.cookie_id,
        shortID: m.attributionToolParams?.airbridge?.short_id,
      },
    });
}
```

### 멱등성 보장

```typescript
export default subscribeEvent({
  eachBatch: async ({ messages }) => {
    for (const m of messages) {
      const existing = await q.findProcessed(m.id);
      if (existing) continue;
      
      await process(m);
      await q.markProcessed(m.id);
    }
  },
});
```

### 배치 처리 최적화

```typescript
export default subscribeEvent({
  eachBatch: async ({ messages, heartbeat }) => {
    // 배치 단위로 DB 조회
    const ids = messages.map(m => m.id);
    const data = await q.findByIds(ids);
    const dataMap = _.keyBy(data, 'id');
    
    // 처리
    for (const m of messages) {
      await process(m, dataMap[m.id]);
      await heartbeat();
    }
  },
  eachBatchSize: 100,
});
```

## 디버깅 팁

### Consumer 상태 확인

```bash
# Redis에서 control config 확인
redis-cli GET r-bus-control

# Kafka consumer group 확인
kafka-consumer-groups --bootstrap-server localhost:9092 --group {groupId} --describe
```

### Outbox 확인

```sql
-- Outbox에 이벤트가 쌓여있는지 확인
SELECT * FROM books.outbox.message
WHERE topic = 'event-name'
ORDER BY created_at DESC
LIMIT 10;
```

### 로그 확인

```bash
# Subscriber 로그
kubectl logs -f deployment/r-bus-services -n production

# Consumer 재시작
kubectl rollout restart deployment/r-bus-services -n production
```

---

## Backfill 빠른 참조

### Backfill 스크립트 템플릿

```typescript
// batch/cmds/one-off-cmds/backfill-{feature}.ts
import delay from 'delay';
import pLimit from 'p-limit';
import type { CommandBuilder } from 'yargs';

export const command = 'backfill-{feature} <startId> <endId>';
export const desc = 'Backfill {description}';

export const builder: CommandBuilder = (yargs) =>
  yargs
    .positional('startId', { demandOption: true, type: 'number' })
    .positional('endId', { demandOption: true, type: 'number' })
    .option('dryRun', { default: true, type: 'boolean' })
    .option('chunkSize', { default: 10000, type: 'number' })
    .option('delay', { default: 0, type: 'number' });

export const retry = async <T>(
  run: () => Promise<T>,
  retries = 3,
): Promise<T> => {
  for (let i = 1; ; i += 1) {
    try {
      return await run();
    } catch (err) {
      if (i >= retries) throw err;
    }
  }
};

export const handler = async (args: {
  startId: number;
  endId: number;
  dryRun: boolean;
  chunkSize: number;
  delay: number;
}) => {
  for (let cur = args.startId; cur < args.endId; cur += args.chunkSize) {
    const end = Math.min(cur + args.chunkSize, args.endId);
    
    // 1. 데이터 조회
    const records = await retry(() => queries.find(cur, end));
    
    // 2. 처리
    const processed = await processRecords(records);
    
    // 3. 저장
    if (!args.dryRun) {
      await retry(() => queries.insert(processed));
    }
    
    // 4. 딜레이
    if (args.delay > 0) {
      await delay(args.delay);
    }
    
    pino.info(`Processed: ${cur} ~ ${end}`);
  }
};
```

### Backfill 실행

```bash
# Dry run (테스트)
yarn batch one-off-cmds backfill-feature 1 100000 --dryRun=true

# 작은 범위로 실제 실행
yarn batch one-off-cmds backfill-feature 1 1000 --dryRun=false

# 전체 실행 (딜레이 추가)
yarn batch one-off-cmds backfill-feature 1 1000000 \
  --dryRun=false \
  --chunkSize=10000 \
  --delay=1000
```

### Airflow 실행

```json
{
  "command": [
    "one-off-cmds",
    "backfill-feature",
    "1",
    "1000000",
    "--dryRun=false",
    "--chunkSize=10000",
    "--delay=1000"
  ]
}
```

### Amplitude 유저 속성 Backfill

```typescript
export const backfillUserProperties = async (users, dryRun) => {
  // 1. 데이터 조회 (병렬)
  const [buildSignup, buildOrder, buildCart] = await Promise.all([
    retry(() => createBuildSignupDateProperties(users)),
    retry(() => createBuildTotalOrderProperties(userIdxs)),
    retry(() => createBuildLastCartItemProperties(userIdxs)),
  ]);
  
  // 2. 이벤트 생성
  const events = users.map(user => ({
    userIdx: user.idx,
    eventType: '$identify',
    userProperties: {
      $setOnce: {  // 기존 값 유지
        ...buildSignup(user.idx),
        ...buildOrder(user.idx),
        ...buildCart(user.idx),
      },
    },
  }));
  
  // 3. 전송
  if (!dryRun) {
    await retry(() => sendBatchEvent('prod', events));
  }
};
```

### 멱등성 보장

```typescript
// 방법 1: ignore
await db('table')
  .insert(records)
  .onConflict('id')
  .ignore();

// 방법 2: merge
await db('table')
  .insert(records)
  .onConflict('id')
  .merge(['updated_at', 'value']);
```

### Concurrency 제어

```typescript
import pLimit from 'p-limit';

const readLimit = pLimit(6);
const writeLimit = pLimit(6);

await Promise.all(
  chunks.map(chunk =>
    readLimit(() => processChunk(chunk))
  )
);
```

---

### ✅ DO

- Outbox 패턴 사용 (트랜잭션과 함께 이벤트 발행)
- 배치 처리로 DB 조회 최적화
- heartbeat 주기적 호출
- 멱등성 보장
- 독립적인 consumer group ID 사용

### ❌ DON'T

- 트랜잭션 밖에서 이벤트 발행
- 개별 메시지마다 DB 조회
- heartbeat 누락 (긴 작업 시)
- 같은 consumer group ID 재사용

## 참고 코드 위치

### 이벤트 정의
- `backends/src/r-bus/cart/index.ts`
- `backends/src/r-bus/orderCompleted/index.ts`
- `backends/src/r-bus/payInfo/index.ts`

### 이벤트 발행
- `backends/src/apps/api/routes/v2/cart/controller.ts`
- `backends/src/apps/books/utils/order/flow/completion/completeOrder.ts`

### Subscriber 구현
- `backends/src/subscribers/services/amplitude-event/cart/cart.ts`
- `backends/src/subscribers/services/amplitude-event/purchase/payInfo.ts`
- `backends/src/subscribers/services/airbridge-event/order/payInfo.ts`
- `backends/src/subscribers/services/log-cart-history/cart.ts`

### 유틸리티
- `backends/src/r-bus/utils.ts`
- `backends/src/subscribers/utils.ts`
- `backends/src/subscribers/services/amplitude-event/utils.ts`
