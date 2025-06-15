;; Decentralized Insurance Pool Contract
;; Allows users to pool funds and claim payouts for verified events

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u100))
(define-constant err-insufficient-funds (err u101))
(define-constant err-pool-not-active (err u102))
(define-constant err-claim-too-large (err u103))
(define-constant err-assessment-failed (err u104))

;; Pool state
(define-data-var pool-active bool true)
(define-data-var total-premiums uint u0)
(define-data-var total-payouts uint u0)
(define-data-var min-premium uint u1000000) ;; 1.0 STX
(define-data-var max-coverage-ratio uint u200) ;; 2.0 (200%)

;; Participant records
(define-map premiums principal uint)
(define-map claims principal uint)
(define-map approved-claims principal bool)


(define-public (submit-claim (amount uint) (proof (buff 128)))
  (begin
    (asserts! (var-get pool-active) err-pool-not-active)
    (let (
        (user-premium (default-to u0 (map-get? premiums tx-sender)))
        (max-claim (/ (* user-premium (var-get max-coverage-ratio)) u100))
      )
      (asserts! (<= amount max-claim) err-claim-too-large)
      
      ;; Store claim for assessment
      (map-set claims tx-sender amount)
      (ok true)
    )
  )
)

(define-public (approve-claim (claimant principal) (approve bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
    (let (
        (claim-amount (default-to u0 (map-get? claims claimant)))
        (pool-balance (stx-get-balance (as-contract tx-sender)))
      )
      (asserts! (<= claim-amount pool-balance) err-insufficient-funds)
      
      (if approve
        (begin
          ;; Process payout
          (map-set approved-claims claimant true)
          (try! (as-contract (stx-transfer? claim-amount tx-sender claimant)))
          (var-set total-payouts (+ (var-get total-payouts) claim-amount))
          (ok true)
        )
        (begin
          ;; Reject claim
          (map-set claims claimant u0)
          (ok false)
        )
      )
    )
  )
)

(define-public (withdraw-premium)
  (begin
    (asserts! (not (var-get pool-active)) err-pool-not-active)
    (let (
        (user-premium (default-to u0 (map-get? premiums tx-sender)))
        (user-claims (default-to u0 (map-get? claims tx-sender)))
        (refund-amount (- user-premium user-claims))
      )
      (asserts! (> refund-amount u0) err-insufficient-funds)
      (map-set premiums tx-sender u0)
      (try! (as-contract (stx-transfer? refund-amount tx-sender tx-sender)))
      (ok true)
    )
  )
)

;; Read-only functions
(define-read-only (get-pool-balance)
  (ok (stx-get-balance (as-contract tx-sender))))

(define-read-only (get-user-premium (user principal))
  (ok (map-get? premiums user)))

