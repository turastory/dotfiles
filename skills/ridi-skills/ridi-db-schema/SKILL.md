---
name: ridi-db-schema
description: Use when locating RIDI database domains, schema files, or key payment, money, book, coupon, and review tables before writing queries, changing backend flows, or investigating data issues.
---

# RIDI DB Schema

This skill is a fast index for schema work.

Start with the SQL files. Use the comprehensive reference only when you need table-level detail.

## When to use

- You need to find which schema file owns a table
- You are tracing order, payment, money, book, coupon, or review data
- You are checking whether code assumptions match the DB
- You need a deeper reference before writing a query or migration

## Primary source

- `backends/src/db/schemas/`

Common files:

- `bom.sql`
- `platform.sql`
- `ownership.sql`
- `platform_finance.sql`
- `ridiselect.sql`
- `outbox.sql`
- `trx.sql`

## Domain map

- Order and checkout
  - `tb_order_transaction`: checkout and payment attempt header with status, pay object, pay type, and external `transaction_id`
  - `tb_order_transaction_contents_book`: per-book order line with price snapshot and rental fields at purchase time
  - `tb_order_transaction_contents_series`: series-level order line for full-set purchase or rental flows
  - `tb_order_transaction_cash`: cash charge extension row attached to a charge order
  - `tb_order_transaction_gift`: gift order detail such as receiver channel and sender-facing message data
  - `tb_order_transaction_subscription`: subscription or recurring-charge extension linked to billing flows

- Payment and settlement
  - `tb_pay_info`: main completed payment record used by order completion, settlement, and non-order grants such as cash or point credit
  - `tb_pay_info_cancel`: cancellation and refund record tied to a completed payment
  - `tb_pay_book`: payment-to-book mapping used in settlement and ownership-related joins
  - `tb_pay_info_subscription`: additional payment record for subscription-specific flows
  - `tb_pay_info_subscription_recur`: recurring billing history for subscription payments
  - `tb_pay_info_periodic_cash_charge_plan`: periodic cash auto-charge plan with next schedule and status
  - `tb_pay_info_tax_deduction`: tax deduction linkage for eligible book purchases
  - `tb_pay_info_price_gap`: recorded gap between nominal order price and actual charged or adjusted amount

- Billing methods
  - `tb_billing`: saved billing method bound to a user, including PG type and billing key
  - `tb_billing_result`: result row for a billing attempt, including PG response and success state
  - `tb_billing_easy_pay`: metadata for easy-pay billing methods

- Money, points, and balance
  - `tb_money_account`: per-user, per-money-type balance summary row
  - `tb_money`: individual charged or granted money bucket with remain amount and expiry
  - `tb_money_spent`: mapping from a payment to the money buckets actually consumed
  - `tb_money_spent_cancel`: reverse linkage used when spent money must be restored on cancellation
  - `tb_money_exhaustion`: scheduled or completed money expiration record
  - `tb_money_property`: auxiliary money or account properties used by balance and finance logic

- Books, series, and pricing
  - `tb_book`: main bookstore book metadata including category, series linkage, visibility, and pricing fields
  - `tb_series`: series header whose `series_id` points to the representative book
  - `tb_book_prices`: current per-book purchase and rental pricing row
  - `tb_book_series_prices`: series-level price row such as discounted full-set prices
  - `tb_category`: category tree used for storefront structure and browse grouping
  - `tb_author`: author master row
  - `tb_book_author`: book-to-author join table

- Ownership and library
  - `tb_user_book`: user ownership or rental row tied to purchase, cancellation, and service type flows
  - `tb_user_book_price`: additional price or settlement share row attached to owned books
  - `tb_user_book_cancel`: ownership cancellation row linked back to payment cancellation
  - `user_book`: ownership summary table used in library-oriented queries
  - `unit_book`: mapping between book ids and library unit ids used by reading and library views

- Gifts
  - `tb_gift_books`: gifted book line with price and settlement-related fields

- Coupons and promotions
  - `tb_coupon_category`: coupon template that defines discount rule, period, and policy
  - `tb_coupon_serial`: issued coupon instance with validity, expiration, and usage state
  - `tb_coupon_use`: mapping between a coupon use and the target order or payment
  - `tb_coupon_usage_bound`: allow or block range for advanced coupon targets such as book, series, or CP
  - `tb_coupon_visibility`: coupon exposure and eligibility control
  - `tb_campaign`: campaign master used for promotion windows and states
  - `tb_random_reward_campaign`: random reward campaign definition
  - `tb_random_reward_entry`: participant and win-state row for random reward campaigns
  - `tb_user_action_campaign`: campaign rule tied to actions such as reading, review, or comment behavior

- Reviews and reading feedback
  - `tb_user_rating`: user rating header for book evaluation flows
  - `tb_user_review`: main review body and display-state row
  - `tb_user_review_comment`: comment row attached to a review
  - `tb_book_review_display`: curated or display-oriented review row used in storefront and reading contexts
  - `user_serial_comment`: serial episode comment row
  - `user_serial_comment_reply`: reply row for serial comments
  - `user_serial_comment_vote`: vote or reaction row for serial comments
  - `annotation`: reading annotation, bookmark, or highlight synchronization row
  - `recent_read`: last-read location and timestamp row per user or device context

- Event outbox
  - `message`: outbox payload row queued for asynchronous delivery to Kafka or similar relays
  - `message_batch`: batch grouping row for outbox delivery flows

- Event participation (스탬프/프로그레스/리스트/캘린더 등 참여 현황 UI CMS)
  - `tb_event_participation`: 이벤트 그룹별 참여 현황 공통 구성 (`event_group_id` unique FK, `participation_type` enum, `title`/`subtitle`/`background_color`/`point_color_scheme`/`reward_provision_text`, `is_visible`+`start_at`+`end_at`로 노출 제어).
  - `tb_event_participation_stamp`: STAMP 타입 전용 스탬프 슬롯 (`participation_id` FK, `order`, `mission_id` **nullable**, `label`, `reward_label`, `placeholder_image_url`, `completion_image_url`). `mission_id`가 NULL이면 수동 지급 슬롯.
  - 달성 판정 원천은 `tb_user_action_campaign_mission_result.won_at`. 참여 현황 레이어는 이 데이터를 뷰 타입별로 투영하고 메타(라벨·이미지·색상)만 덧붙인다.
  - 파일럿은 GrowthBook 플래그 `productpay-event-participation-group-stamp`. DB 경로가 정식화된 후 deprecate 예정.

- Subscriptions
  - `tb_user_ridi_select_ticket`: RIDI Select subscription ticket with validity period and currency context
  - `tb_user_ridi_select_book`: link between a user, a Select entitlement, and a book
  - `tb_user_kanta_subscription`: Kanta subscription master row
  - `tb_user_kanta_subscription_plan`: Kanta plan row with schedule and status
  - `tb_user_kanta_subscription_products`: product composition rows for Kanta subscriptions

- CRM and campaign targeting
  - `tb_campaign_optout`: opt-out row for campaign or messaging delivery
  - `tb_campaign_excluded_abuser`: exclusion list row for abuse filtering in campaign sends

- CP and finance operations
  - `cp_point`: CP-facing point and settlement operation row used in finance workflows

- Infrastructure
  - `tb_tid_incr`: monotonic id source used for transaction or order id issuance

## Things to remember

- `tb_pay_info` is broader than just book orders
- Money usage follows FIFO-style balance consumption
- Book and series relations have historical fields and conventions; verify in SQL before assuming constraints
- If a skill and SQL disagree, trust `backends/src/db/schemas/` first -> Update skill later to make it up-to-date

## Reference document

For a larger table-by-table guide, open:

- `.cursor/skills/ridi-db-schema/DB_SCHEMA_COMPREHENSIVE.md`

Use the reference document only when the short index is not enough.

## Related skills

- `ridi-project-structure`
- `ridi-event-structure`
