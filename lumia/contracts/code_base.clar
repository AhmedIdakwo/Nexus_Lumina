;; Medical Research Funding Platform

;; Error codes
(define-constant ERR-UNAUTHORIZED-RESEARCHER (err u100))
(define-constant ERR-INSUFFICIENT-RESEARCH-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))
(define-constant ERR-RESEARCH-PROPOSAL-EXPIRED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDING-DEPOSIT (err u104))
(define-constant ERR-BELOW-MINIMUM-FUNDING-THRESHOLD (err u105))
(define-constant ERR-INVALID-RESEARCH-IMPACT (err u106))
(define-constant ERR-ARITHMETIC-OVERFLOW (err u107))
(define-constant ERR-INVALID-RECIPIENT (err u108))
(define-constant ERR-ZERO-AMOUNT (err u109))
(define-constant ERR-NO-RESEARCH-PROJECT-EXISTS (err u110))

;; Constants
(define-constant PLATFORM-ADMINISTRATOR tx-sender)
(define-constant PROPOSAL-REVIEW-EXPIRY-BLOCKS u900) ;; 15 minutes in blocks
(define-constant REQUIRED-FUNDING-RATIO u150) ;; 150%
(define-constant LIQUIDATION-THRESHOLD-RATIO u120) ;; 120%
(define-constant MINIMUM-RESEARCH-TOKEN-MINT u100000000) ;; 1.00 tokens (8 decimals)
(define-constant MAXIMUM-RESEARCH-IMPACT-SCORE u1000000000000) ;; Set reasonable maximum impact score
(define-constant MAXIMUM-UINT-VALUE u340282366920938463463374607431768211455) ;; 2^128 - 1

;; Data variables
(define-data-var proposal-last-review-block uint u0)
(define-data-var current-research-impact-score uint u0)
(define-data-var total-research-tokens-supply uint u0)

;; Data maps
(define-map research-token-account-balances principal uint)
(define-map research-project-funding-positions
    principal
    {
        funding-amount-locked: uint,
        research-tokens-issued: uint,
        entry-research-impact: uint
    }
)

;; Safe math functions
(define-private (safe-multiply-numbers (first-number uint) (second-number uint))
    (let ((multiplication-result (* first-number second-number)))
        (asserts! (or (is-eq first-number u0) (is-eq (/ multiplication-result first-number) second-number)) ERR-ARITHMETIC-OVERFLOW)
        (ok multiplication-result)))

(define-private (safe-add-numbers (first-number uint) (second-number uint))
    (let ((addition-result (+ first-number second-number)))
        (asserts! (>= addition-result first-number) ERR-ARITHMETIC-OVERFLOW)
        (ok addition-result)))

(define-private (safe-subtract-numbers (minuend uint) (subtrahend uint))
    (begin
        (asserts! (>= minuend subtrahend) ERR-ARITHMETIC-OVERFLOW)
        (ok (- minuend subtrahend))))

;; Read-only functions
(define-read-only (get-account-token-balance (account-holder principal))
    (default-to u0 (map-get? research-token-account-balances account-holder))
)

(define-read-only (get-total-research-tokens-supply)
    (var-get total-research-tokens-supply)
)

(define-read-only (get-current-research-impact-score)
    (var-get current-research-impact-score)
)

(define-read-only (get-research-project-details (researcher principal))
    (map-get? research-project-funding-positions researcher)
)

(define-read-only (calculate-project-funding-ratio (researcher principal))
    (let (
        (project-details (unwrap! (get-research-project-details researcher) (err u0)))
        (current-impact-score (var-get current-research-impact-score))
    )
    (if (> (get research-tokens-issued project-details) u0)
        (match (safe-multiply-numbers (get funding-amount-locked project-details) u100)
            success1 (match (safe-multiply-numbers success1 u100)
                success2 (match (safe-multiply-numbers (get research-tokens-issued project-details) current-impact-score)
                    denominator (ok (/ success2 denominator))
                    error ERR-ARITHMETIC-OVERFLOW)
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW)
        (err u0)))
)

;; Private functions
(define-private (execute-token-transfer (sender-account principal) (recipient-account principal) (transfer-quantity uint))
    (let (
        (sender-current-balance (get-account-token-balance sender-account))
    )
    ;; Secondary validations in case this function is called directly
    (asserts! (> transfer-quantity u0) ERR-ZERO-AMOUNT)
    (asserts! (not (is-eq sender-account recipient-account)) ERR-INVALID-RECIPIENT)
    (asserts! (>= sender-current-balance transfer-quantity) ERR-INSUFFICIENT-RESEARCH-TOKEN-BALANCE)
    (asserts! (is-some (map-get? research-token-account-balances sender-account)) ERR-UNAUTHORIZED-RESEARCHER)
    
    (match (safe-add-numbers (get-account-token-balance recipient-account) transfer-quantity)
        recipient-updated-balance
            (match (safe-subtract-numbers sender-current-balance transfer-quantity)
                sender-updated-balance
                    (begin
                        (map-set research-token-account-balances sender-account sender-updated-balance)
                        (map-set research-token-account-balances recipient-account recipient-updated-balance)
                        (ok true))
                error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

;; Public functions
(define-public (update-research-impact-score (updated-score uint))
    (begin
        (asserts! (is-eq tx-sender PLATFORM-ADMINISTRATOR) ERR-UNAUTHORIZED-RESEARCHER)
        (asserts! (> updated-score u0) ERR-INVALID-RESEARCH-IMPACT)
        (asserts! (< updated-score MAXIMUM-RESEARCH-IMPACT-SCORE) ERR-INVALID-RESEARCH-IMPACT)
        (var-set current-research-impact-score updated-score)
        (var-set proposal-last-review-block block-height)
        (ok true))
)

(define-public (mint-research-project-tokens (token-quantity uint))
    (let (
        (current-impact-score (var-get current-research-impact-score))
    )
    (asserts! (> token-quantity u0) ERR-ZERO-AMOUNT)
    (asserts! (>= token-quantity MINIMUM-RESEARCH-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
    (asserts! (<= (- block-height (var-get proposal-last-review-block)) 
                 PROPOSAL-REVIEW-EXPIRY-BLOCKS) 
              ERR-RESEARCH-PROPOSAL-EXPIRED)
    
    (match (safe-multiply-numbers token-quantity (/ current-impact-score u100))
        required-base-funding 
        (match (safe-multiply-numbers required-base-funding (/ REQUIRED-FUNDING-RATIO u100))
            minimum-funding-required
            (match (stx-transfer? minimum-funding-required tx-sender (as-contract tx-sender))
                success
                (begin
                    (map-set research-project-funding-positions tx-sender
                        {
                            funding-amount-locked: minimum-funding-required,
                            research-tokens-issued: token-quantity,
                            entry-research-impact: current-impact-score
                        })
                    (match (safe-add-numbers (get-account-token-balance tx-sender) token-quantity)
                        updated-balance
                        (begin
                            (map-set research-token-account-balances tx-sender updated-balance)
                            (match (safe-add-numbers (var-get total-research-tokens-supply) token-quantity)
                                updated-supply
                                (begin
                                    (var-set total-research-tokens-supply updated-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-INSUFFICIENT-FUNDING-DEPOSIT)
            error ERR-ARITHMETIC-OVERFLOW)
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (burn-research-project-tokens (token-quantity uint))
    (let (
        (project-details (unwrap! (get-research-project-details tx-sender) 
                               ERR-NO-RESEARCH-PROJECT-EXISTS))
        (account-balance (get-account-token-balance tx-sender))
    )
    (asserts! (> token-quantity u0) ERR-ZERO-AMOUNT)
    (asserts! (>= account-balance token-quantity) ERR-INSUFFICIENT-RESEARCH-TOKEN-BALANCE)
    (asserts! (>= (get research-tokens-issued project-details) token-quantity) 
              ERR-UNAUTHORIZED-RESEARCHER)
    
    (match (safe-multiply-numbers (get funding-amount-locked project-details) token-quantity)
        funding-calculation
        (let (
            (funding-return-amount (/ funding-calculation 
                                       (get research-tokens-issued project-details)))
        )
        
        (try! (as-contract (stx-transfer? funding-return-amount
                                         (as-contract tx-sender)
                                         tx-sender)))
        
        (match (safe-subtract-numbers (get funding-amount-locked project-details) 
                            funding-return-amount)
            updated-funding-amount
            (match (safe-subtract-numbers (get research-tokens-issued project-details) 
                                token-quantity)
                updated-token-amount
                (begin
                    (map-set research-project-funding-positions tx-sender
                        {
                            funding-amount-locked: updated-funding-amount,
                            research-tokens-issued: updated-token-amount,
                            entry-research-impact: (var-get current-research-impact-score)
                        })
                    
                    (match (safe-subtract-numbers account-balance token-quantity)
                        updated-balance
                        (begin
                            (map-set research-token-account-balances tx-sender updated-balance)
                            (match (safe-subtract-numbers (var-get total-research-tokens-supply) 
                                                token-quantity)
                                updated-supply
                                (begin
                                    (var-set total-research-tokens-supply updated-supply)
                                    (ok true))
                                error ERR-ARITHMETIC-OVERFLOW))
                        error ERR-ARITHMETIC-OVERFLOW))
                error ERR-ARITHMETIC-OVERFLOW)
            error ERR-ARITHMETIC-OVERFLOW))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (transfer-research-tokens (recipient-account principal) (transfer-quantity uint))
    (begin
        ;; Input validation
        (asserts! (> transfer-quantity u0) ERR-ZERO-AMOUNT)
        (asserts! (<= transfer-quantity (get-account-token-balance tx-sender)) ERR-INSUFFICIENT-RESEARCH-TOKEN-BALANCE)
        (asserts! (not (is-eq tx-sender recipient-account)) ERR-INVALID-RECIPIENT)
        
        ;; Only proceed with transfer if validations pass
        (execute-token-transfer tx-sender recipient-account transfer-quantity))
)

(define-public (add-funding-to-project (funding-quantity uint))
    (let (
        (project-details (default-to 
            {
                funding-amount-locked: u0, 
                research-tokens-issued: u0, 
                entry-research-impact: u0
            }
            (get-research-project-details tx-sender)))
    )
    (asserts! (> funding-quantity u0) ERR-ZERO-AMOUNT)
    (try! (stx-transfer? funding-quantity tx-sender (as-contract tx-sender)))
    
    (match (safe-add-numbers (get funding-amount-locked project-details) 
                    funding-quantity)
        updated-funding-amount
        (begin
            (map-set research-project-funding-positions tx-sender
                {
                    funding-amount-locked: updated-funding-amount,
                    research-tokens-issued: (get research-tokens-issued project-details),
                    entry-research-impact: (var-get current-research-impact-score)
                })
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)

(define-public (liquidate-research-project (project-owner principal))
    (let (
        (project-details (unwrap! (get-research-project-details project-owner) 
                               ERR-NO-RESEARCH-PROJECT-EXISTS))
        (current-funding-ratio (unwrap! (calculate-project-funding-ratio project-owner) 
                                         ERR-UNAUTHORIZED-RESEARCHER))
    )
    (asserts! (< current-funding-ratio LIQUIDATION-THRESHOLD-RATIO) 
              ERR-UNAUTHORIZED-RESEARCHER)
    
    ;; Transfer funding to liquidator
    (try! (as-contract (stx-transfer? (get funding-amount-locked project-details)
                                     (as-contract tx-sender)
                                     tx-sender)))
    
    ;; Clear the project position
    (map-delete research-project-funding-positions project-owner)
    
    ;; Burn the research tokens
    (map-set research-token-account-balances project-owner u0)
    (match (safe-subtract-numbers (var-get total-research-tokens-supply) 
                         (get research-tokens-issued project-details))
        updated-supply
        (begin
            (var-set total-research-tokens-supply updated-supply)
            (ok true))
        error ERR-ARITHMETIC-OVERFLOW))
)