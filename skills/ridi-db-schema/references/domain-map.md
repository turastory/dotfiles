# RIDI DB Domain Map

Start with `backends/src/db/schemas/`. If this reference and SQL disagree, trust SQL and update this reference later.

## Order And Checkout

- `tb_order_transaction`: checkout and payment attempt header with status, pay object, pay type, and external `transaction_id`
- `tb_order_transaction_contents_book`: per-book order line with price snapshot and rental fields at purchase time
- `tb_order_transaction_contents_series`: series-level order line for full-set purchase or rental flows
- `tb_order_transaction_cash`: cash charge extension row attached to a charge order
- `tb_order_transaction_gift`: gift order detail such as receiver channel and sender-facing message data
- `tb_order_transaction_subscription`: subscription or recurring-charge extension linked to billing flows

## Payment And Settlement

- `tb_pay_info`: main completed payment record used by order completion, settlement, and non-order grants such as cash or point credit
- `tb_pay_info_cancel`: cancellation and refund record tied to a completed payment
- `tb_pay_book`: payment-to-book mapping used in settlement and ownership-related joins
- `tb_pay_info_subscription`: additional payment record for subscription-specific flows
- `tb_pay_info_subscription_recur`: recurring billing history for subscription payments
- `tb_pay_info_periodic_cash_charge_plan`: periodic cash auto-charge plan with next schedule and status
- `tb_pay_info_tax_deduction`: tax deduction linkage for eligible book purchases
- `tb_pay_info_price_gap`: recorded gap between nominal order price and actual charged or adjusted amount

## Billing Methods

- `tb_billing`: saved billing method bound to a user, including PG type and billing key
- `tb_billing_result`: result row for a billing attempt, including PG response and success state
- `tb_billing_easy_pay`: metadata for easy-pay billing methods

## Money, Points, And Balance

- `tb_money_account`: per-user, per-money-type balance summary row
- `tb_money`: individual charged or granted money bucket with remain amount and expiry
- `tb_money_spent`: mapping from a payment to the money buckets actually consumed
- `tb_money_spent_cancel`: reverse linkage used when spent money must be restored on cancellation
- `tb_money_exhaustion`: scheduled or completed money expiration record
- `tb_money_property`: auxiliary money or account properties used by balance and finance logic

## Books, Series, And Pricing

- `tb_book`: main bookstore book metadata including category, series linkage, visibility, and pricing fields
- `tb_series`: series header whose `series_id` points to the representative book
- `tb_book_prices`: current per-book purchase and rental pricing row
- `tb_book_series_prices`: series-level price row such as discounted full-set prices
- `tb_category`: category tree used for storefront structure and browse grouping
- `tb_author`: author master row
- `tb_book_author`: book-to-author join table

## Ownership And Library

- `tb_user_book`: user ownership or rental row tied to purchase, cancellation, and service type flows
- `tb_user_book_price`: additional price or settlement share row attached to owned books
- `tb_user_book_cancel`: ownership cancellation row linked back to payment cancellation
- `user_book`: ownership summary table used in library-oriented queries
- `unit_book`: mapping between book ids and library unit ids used by reading and library views

## Gifts

- `tb_gift_books`: gifted book line with price and settlement-related fields

## Coupons And Promotions

- `tb_coupon_category`: coupon template that defines discount rule, period, and policy
- `tb_coupon_serial`: issued coupon instance with validity, expiration, and usage state
- `tb_coupon_use`: mapping between a coupon use and the target order or payment
- `tb_coupon_usage_bound`: allow or block range for advanced coupon targets such as book, series, or CP
- `tb_coupon_visibility`: coupon exposure and eligibility control
- `tb_campaign`: campaign master used for promotion windows and states
- `tb_random_reward_campaign`: random reward campaign definition
- `tb_random_reward_entry`: participant and win-state row for random reward campaigns
- `tb_user_action_campaign`: campaign rule tied to actions such as reading, review, or comment behavior

## Reviews And Reading Feedback

- `tb_user_rating`: user rating header for book evaluation flows
- `tb_user_review`: main review body and display-state row
- `tb_user_review_comment`: comment row attached to a review
- `tb_book_review_display`: curated or display-oriented review row used in storefront and reading contexts
- `user_serial_comment`: serial episode comment row
- `user_serial_comment_reply`: reply row for serial comments
- `user_serial_comment_vote`: vote or reaction row for serial comments
- `annotation`: reading annotation, bookmark, or highlight synchronization row
- `recent_read`: last-read location and timestamp row per user or device context

## Event Outbox

- `message`: outbox payload row queued for asynchronous delivery to Kafka or similar relays
- `message_batch`: batch grouping row for outbox delivery flows

## Event Participation

스탬프/프로그레스/리스트/캘린더 등 이벤트 참여 현황 UI CMS 도메인이다.

- `tb_event_participation`: 이벤트 그룹별 참여 현황 공통 구성 (`event_group_id` unique FK, `participation_type` enum, `title`/`subtitle`/`background_color`/`point_color_scheme`/`reward_provision_text`, `is_visible`+`start_at`+`end_at`로 노출 제어).
- `tb_event_participation_stamp`: STAMP 타입 전용 스탬프 슬롯 (`participation_id` FK, `order`, `mission_id` nullable, `label`, `reward_label`, `placeholder_image_filename`, `completion_image_filename`). `mission_id`가 NULL이면 수동 지급 슬롯.
- `tb_event_participation_progress_milestone`: PROGRESS 타입 구간 구성 (`participation_id` FK, `mission_id`, `order`, `label`, `reward_label`). threshold/metric은 이 테이블이 아니라 연결된 mission objective에서 파생된다.
- `tb_event_participation_checklist_item`: CHECKLIST 타입 항목 구성 (`participation_id` FK, `order`, `item_type`, `label`, `reward_label`, `link_url`).
- `tb_event_participation_checklist_item_mission`: CHECKLIST item과 action campaign mission 매핑. 한 item이 여러 mission을 가질 수 있다.
- Mission objective는 `tb_user_action_campaign_mission_action_property`를 `buildActionData`로 해석해 얻는다. `PURCHASE_AMOUNT`는 금액 metric, 그 외 count/bookCount 계열은 count metric으로 투영된다.
- 진행값은 `tb_user_action_campaign_mission_activity` 또는 구매금액 집계에서 계산하고, 완료/리워드 확정은 `tb_user_action_campaign_mission_result.won_at` 및 `tb_user_action_campaign_mission_reward_history`를 기준으로 본다. `reward_provision_text`가 있으면 수동 안내가 우선한다.
- 파일럿은 GrowthBook 플래그 `productpay-event-participation-group-stamp`. DB 경로가 정식화된 후 deprecate 예정.

## Subscriptions

- `tb_user_ridi_select_ticket`: RIDI Select subscription ticket with validity period and currency context
- `tb_user_ridi_select_book`: link between a user, a Select entitlement, and a book
- `tb_user_kanta_subscription`: Kanta subscription master row
- `tb_user_kanta_subscription_plan`: Kanta plan row with schedule and status
- `tb_user_kanta_subscription_products`: product composition rows for Kanta subscriptions

## CRM And Campaign Targeting

- `tb_campaign_optout`: opt-out row for campaign or messaging delivery
- `tb_campaign_excluded_abuser`: exclusion list row for abuse filtering in campaign sends

## CP And Finance Operations

- `cp_point`: CP-facing point and settlement operation row used in finance workflows

## Infrastructure

- `tb_tid_incr`: monotonic id source used for transaction or order id issuance
