;; Medical Research Funding Platform 

;; Error codes
(define-constant ERR-UNAUTHORIZED-RESEARCHER (err u100))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))
(define-constant ERR-BELOW-FUNDING-THRESHOLD (err u103))
(define-constant ERR-INVALID-IMPACT-SCORE (err u104))

;; Constants
(define-constant PLATFORM-ADMINISTRATOR tx-sender)
(define-constant MINIMUM-RESEARCH-TOKEN-MINT u100000000) ;; 1.00 tokens
(define-constant MAXIMUM-IMPACT-SCORE u1000000000) ;; Max impact score
(define-constant REQUIRED-FUNDING-RATIO u150) ;; 150%

;; Data variables
(define-data-var total-research-tokens-supply uint u0)
(define-data-var current-research-impact-score uint u0)

;; Data maps
(define-map research-token-balances principal uint)
(define-map research-project-details 
    principal 
    {
        tokens-issued: uint,
        funding-locked: uint,
        impact-rating: uint
    }
)

;; Read-only functions
(define-read-only (get-token-balance (researcher principal))
    (default-to u0 (map-get? research-token-balances researcher))
)

(define-read-only (get-total-token-supply)
    (var-get total-research-tokens-supply)
)

(define-read-only (get-current-impact-score)
    (var-get current-research-impact-score)
)

;; Public functions
(define-public (update-impact-score (new-score uint))
    (begin
        (asserts! (is-eq tx-sender PLATFORM-ADMINISTRATOR) ERR-UNAUTHORIZED-RESEARCHER)
        (asserts! (> new-score u0) ERR-INVALID-IMPACT-SCORE)
        (asserts! (< new-score MAXIMUM-IMPACT-SCORE) ERR-INVALID-IMPACT-SCORE)
        
        (var-set current-research-impact-score new-score)
        (ok true)
    )
)

(define-public (mint-research-tokens (token-quantity uint))
    (let (
        (current-impact-score (var-get current-research-impact-score))
        (required-funding (/ (* token-quantity current-impact-score REQUIRED-FUNDING-RATIO) u10000))
    )
    (begin
        ;; Validate token amount and impact
        (asserts! (>= token-quantity MINIMUM-RESEARCH-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
        (asserts! (>= current-impact-score u100) ERR-BELOW-FUNDING-THRESHOLD)
        
        ;; Transfer required funding
        (try! (stx-transfer? required-funding tx-sender (as-contract tx-sender)))
        
        ;; Update researcher's token balance
        (map-set research-token-balances tx-sender 
            (+ (get-token-balance tx-sender) token-quantity))
        
        ;; Record project details
        (map-set research-project-details tx-sender {
            tokens-issued: token-quantity,
            funding-locked: required-funding,
            impact-rating: current-impact-score
        })
        
        ;; Update total supply
        (var-set total-research-tokens-supply 
            (+ (var-get total-research-tokens-supply) token-quantity))
        
        (ok true)
    )
)

(define-public (transfer-research-tokens (recipient principal) (amount uint))
    (begin
        ;; Validate transfer
        (asserts! (>= (get-token-balance tx-sender) amount) ERR-INSUFFICIENT-TOKEN-BALANCE)
        
        ;; Deduct from sender
        (map-set research-token-balances tx-sender 
            (- (get-token-balance tx-sender) amount))
        
        ;; Add to recipient
        (map-set research-token-balances recipient 
            (+ (get-token-balance recipient) amount))
        
        (ok true)
    )
)