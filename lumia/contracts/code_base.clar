;; Medical Research Funding Platform - V1
;; Commit Message: Initial setup of basic research token and funding mechanism

;; Error codes
(define-constant ERR-UNAUTHORIZED-RESEARCHER (err u100))
(define-constant ERR-INSUFFICIENT-TOKEN-BALANCE (err u101))
(define-constant ERR-INVALID-TOKEN-AMOUNT (err u102))

;; Constants
(define-constant PLATFORM-ADMINISTRATOR tx-sender)
(define-constant MINIMUM-RESEARCH-TOKEN-MINT u100000000) ;; 1.00 tokens

;; Data variables
(define-data-var total-research-tokens-supply uint u0)

;; Data maps
(define-map research-token-balances principal uint)

;; Read-only functions
(define-read-only (get-token-balance (researcher principal))
    (default-to u0 (map-get? research-token-balances researcher))
)

(define-read-only (get-total-token-supply)
    (var-get total-research-tokens-supply)
)

;; Public functions
(define-public (mint-research-tokens (token-quantity uint))
    (begin
        ;; Validate token amount
        (asserts! (>= token-quantity MINIMUM-RESEARCH-TOKEN-MINT) ERR-INVALID-TOKEN-AMOUNT)
        
        ;; Update researcher's token balance
        (map-set research-token-balances tx-sender 
            (+ (get-token-balance tx-sender) token-quantity))
        
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