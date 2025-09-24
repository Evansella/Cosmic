;; Space Mission Funding Smart Contract  
;; Project Description: A decentralised space mission contract on Stacks. The mission commander sets a cost and duration, investors fund the mission, and phases are executed only if stakeholders approve through voting. If the cost isn't met, investors can claim refunds.

;; Constants
(define-constant ERR_NOT_COMMANDER (err u100))
(define-constant ERR_MISSION_ALREADY_LAUNCHED (err u101))
(define-constant ERR_INVESTOR_NOT_FOUND (err u102))
(define-constant ERR_LAUNCH_WINDOW_CLOSED (err u103))
(define-constant ERR_FUNDING_TARGET_MISSED (err u104))
(define-constant ERR_INSUFFICIENT_MISSION_FUNDS (err u105))
(define-constant ERR_INVALID_INVESTMENT (err u106))
(define-constant ERR_INVALID_MISSION_DURATION (err u107))

;; Data Variables
(define-data-var mission-commander (optional principal) none)
(define-data-var mission-cost uint u0)
(define-data-var funds-secured uint u0)
(define-data-var current-phase uint u0)
(define-data-var go-votes uint u0)
(define-data-var no-go-votes uint u0)
(define-data-var total-investors uint u0)
(define-data-var launch-window-end uint u0)
(define-data-var mission-state (string-ascii 20) "not_started")

;; Maps
(define-map investor-stakes principal uint)
(define-map mission-phases uint {description: (string-utf8 256), cost: uint})

;; Private Functions
(define-private (is-mission-commander)
  (is-eq (some tx-sender) (var-get mission-commander))
)

(define-private (is-launch-window-open)
  (and
    (is-eq (var-get mission-state) "funding")
    (<= stacks-block-height (var-get launch-window-end))
  )
)

;; Public Functions
(define-public (initialize-mission (cost uint) (duration uint))
  (begin
    (asserts! (is-none (var-get mission-commander)) ERR_MISSION_ALREADY_LAUNCHED)
    (asserts! (> cost u0) ERR_INVALID_INVESTMENT)
    (asserts! (and (> duration u0) (<= duration u52560)) ERR_INVALID_MISSION_DURATION)
    (var-set mission-commander (some tx-sender))
    (var-set mission-cost cost)
    (var-set launch-window-end (+ stacks-block-height duration))
    (var-set mission-state "funding")
    (ok true)
  )
)

(define-public (invest-in-mission (amount uint))
  (let (
    (current-stake (default-to u0 (map-get? investor-stakes tx-sender)))
  )
    (asserts! (is-launch-window-open) ERR_LAUNCH_WINDOW_CLOSED)
    (asserts! (> amount u0) ERR_INVALID_INVESTMENT)
    (asserts! (<= (+ (var-get funds-secured) amount) (var-get mission-cost)) ERR_FUNDING_TARGET_MISSED)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set funds-secured (+ (var-get funds-secured) amount))
    (map-set investor-stakes tx-sender (+ current-stake amount))
    (if (is-eq current-stake u0)
      (var-set total-investors (+ (var-get total-investors) u1))
      true
    )
    (ok true)
  )
)

(define-public (vote-on-phase (approve bool))
  (let ((stake (default-to u0 (map-get? investor-stakes tx-sender))))
    (asserts! (> stake u0) ERR_INVESTOR_NOT_FOUND)
    (asserts! (is-eq (var-get mission-state) "phase_review") ERR_NOT_COMMANDER)
    (if approve
      (var-set go-votes (+ (var-get go-votes) stake))
      (var-set no-go-votes (+ (var-get no-go-votes) stake))
    )
    (ok true)
  )
)

(define-public (begin-phase-review)
  (begin
    (asserts! (is-mission-commander) ERR_NOT_COMMANDER)
    (asserts! (is-eq (var-get mission-state) "funding") ERR_NOT_COMMANDER)
    (var-set mission-state "phase_review")
    (var-set go-votes u0)
    (var-set no-go-votes u0)
    (ok true)
  )
)

(define-public (complete-phase-review)
  (begin
    (asserts! (is-mission-commander) ERR_NOT_COMMANDER)
    (asserts! (is-eq (var-get mission-state) "phase_review") ERR_NOT_COMMANDER)
    (let ((total-votes (+ (var-get go-votes) (var-get no-go-votes))))
      (asserts! (> total-votes u0) ERR_INVESTOR_NOT_FOUND)
      (if (> (var-get go-votes) (var-get no-go-votes))
        (begin
          (var-set current-phase (+ (var-get current-phase) u1))
          (var-set mission-state "funding")
          (ok true)
        )
        (begin
          (var-set mission-state "funding")
          (err u308)  ;; ERR_PHASE_REJECTED
        )
      )
    )
  )
)

(define-public (add-mission-phase (description (string-utf8 256)) (cost uint))
  (begin
    (asserts! (is-mission-commander) ERR_NOT_COMMANDER)
    (asserts! (> cost u0) ERR_INVALID_INVESTMENT)
    (asserts! (<= (len description) u256) (err u309))  ;; ERR_INVALID_PHASE_DESC
    (map-set mission-phases (var-get current-phase) {description: description, cost: cost})
    (ok true)
  )
)

(define-public (release-mission-funds (amount uint))
  (begin
    (asserts! (is-mission-commander) ERR_NOT_COMMANDER)
    (asserts! (> amount u0) ERR_INVALID_INVESTMENT)
    (asserts! (<= amount (var-get funds-secured)) ERR_INSUFFICIENT_MISSION_FUNDS)
    (as-contract (stx-transfer? amount tx-sender (unwrap! (var-get mission-commander) ERR_INVESTOR_NOT_FOUND)))
  )
)

(define-public (abort-mission-refund)
  (let ((stake (default-to u0 (map-get? investor-stakes tx-sender))))
    (asserts! (and
      (> stacks-block-height (var-get launch-window-end))
      (< (var-get funds-secured) (var-get mission-cost))
    ) ERR_NOT_COMMANDER)
    (asserts! (> stake u0) ERR_INVESTOR_NOT_FOUND)
    (map-delete investor-stakes tx-sender)
    (as-contract (stx-transfer? stake tx-sender tx-sender))
  )
)

;; Read-only Functions
(define-read-only (get-mission-status)
  (ok {
    commander: (var-get mission-commander),
    cost: (var-get mission-cost),
    secured: (var-get funds-secured),
    launch-window-end: (var-get launch-window-end),
    state: (var-get mission-state),
    current-phase: (var-get current-phase)
  })
)

(define-read-only (get-investor-stake (investor principal))
  (ok (default-to u0 (map-get? investor-stakes investor)))
)

(define-read-only (get-phase-info (phase-id uint))
  (map-get? mission-phases phase-id)
)