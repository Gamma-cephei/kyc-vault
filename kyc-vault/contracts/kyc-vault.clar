;; KYC Vault - Self-Sovereign Identity Verification Contract
;; A decentralized KYC verification and storage system on Stacks blockchain

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-EXPIRED (err u410))

;; Data variables
(define-data-var next-kyc-id uint u1)
(define-data-var verification-fee uint u1000000) ;; 1 STX in microSTX

;; KYC Status enumeration
(define-constant KYC-PENDING u0)
(define-constant KYC-VERIFIED u1)
(define-constant KYC-REJECTED u2)
(define-constant KYC-EXPIRED u3)

;; Data maps
(define-map kyc-records
  { user: principal }
  {
    kyc-id: uint,
    status: uint,
    verification-level: uint, ;; 1=basic, 2=enhanced, 3=institutional
    verified-at: uint,
    expires-at: uint,
    document-hash: (buff 32),
    verifier: principal,
    metadata-uri: (string-ascii 256)
  }
)

(define-map authorized-verifiers
  { verifier: principal }
  {
    authorized: bool,
    verification-level: uint,
    authorized-at: uint
  }
)

(define-map kyc-permissions
  { user: principal, accessor: principal }
  {
    granted: bool,
    permission-level: uint, ;; 1=basic info, 2=detailed info, 3=full access
    granted-at: uint,
    expires-at: uint
  }
)

(define-map user-preferences
  { user: principal }
  {
    auto-approve-level: uint, ;; Auto-approve access requests up to this level
    notification-enabled: bool,
    data-retention-period: uint ;; Days to retain data
  }
)

;; Authorization functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    entry (get authorized entry)
    false
  )
)

;; Administrative functions
(define-public (add-verifier (verifier principal) (level uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (and (>= level u1) (<= level u3)) ERR-INVALID-INPUT)
    (ok (map-set authorized-verifiers
      { verifier: verifier }
      {
        authorized: true,
        verification-level: level,
        authorized-at: block-height
      }
    ))
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (ok (map-delete authorized-verifiers { verifier: verifier }))
  )
)

(define-public (set-verification-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (ok (var-set verification-fee new-fee))
  )
)

;; KYC submission and verification functions
(define-public (submit-kyc-request (document-hash (buff 32)) (verification-level uint) (metadata-uri (string-ascii 256)))
  (let
    (
      (current-kyc-id (var-get next-kyc-id))
      (fee (var-get verification-fee))
    )
    (begin
      (asserts! (and (>= verification-level u1) (<= verification-level u3)) ERR-INVALID-INPUT)
      (asserts! (is-none (map-get? kyc-records { user: tx-sender })) ERR-ALREADY-EXISTS)
      
      ;; Transfer fee to contract
      (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
      
      ;; Create KYC record
      (map-set kyc-records
        { user: tx-sender }
        {
          kyc-id: current-kyc-id,
          status: KYC-PENDING,
          verification-level: verification-level,
          verified-at: u0,
          expires-at: u0,
          document-hash: document-hash,
          verifier: tx-sender, ;; Will be updated when verified
          metadata-uri: metadata-uri
        }
      )
      
      ;; Increment KYC ID counter
      (var-set next-kyc-id (+ current-kyc-id u1))
      
      (ok current-kyc-id)
    )
  )
)

(define-public (verify-kyc (user principal) (approved bool) (expiry-blocks uint))
  (let
    (
      (kyc-record (unwrap! (map-get? kyc-records { user: user }) ERR-NOT-FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-UNAUTHORIZED))
    )
    (begin
      (asserts! (get authorized verifier-info) ERR-UNAUTHORIZED)
      (asserts! (>= (get verification-level verifier-info) (get verification-level kyc-record)) ERR-UNAUTHORIZED)
      (asserts! (is-eq (get status kyc-record) KYC-PENDING) ERR-INVALID-INPUT)
      
      (ok (map-set kyc-records
        { user: user }
        (merge kyc-record {
          status: (if approved KYC-VERIFIED KYC-REJECTED),
          verified-at: block-height,
          expires-at: (if approved (+ block-height expiry-blocks) u0),
          verifier: tx-sender
        })
      ))
    )
  )
)

;; Access control functions
(define-public (grant-access (accessor principal) (permission-level uint) (duration-blocks uint))
  (let
    (
      (kyc-record (unwrap! (map-get? kyc-records { user: tx-sender }) ERR-NOT-FOUND))
    )
    (begin
      (asserts! (is-eq (get status kyc-record) KYC-VERIFIED) ERR-UNAUTHORIZED)
      (asserts! (and (>= permission-level u1) (<= permission-level u3)) ERR-INVALID-INPUT)
      (asserts! (<= permission-level (get verification-level kyc-record)) ERR-UNAUTHORIZED)
      
      (ok (map-set kyc-permissions
        { user: tx-sender, accessor: accessor }
        {
          granted: true,
          permission-level: permission-level,
          granted-at: block-height,
          expires-at: (+ block-height duration-blocks)
        }
      ))
    )
  )
)

(define-public (revoke-access (accessor principal))
  (begin
    (ok (map-delete kyc-permissions { user: tx-sender, accessor: accessor }))
  )
)

;; User preference functions
(define-public (set-user-preferences (auto-approve-level uint) (notification-enabled bool) (retention-period uint))
  (begin
    (asserts! (and (>= auto-approve-level u0) (<= auto-approve-level u3)) ERR-INVALID-INPUT)
    (ok (map-set user-preferences
      { user: tx-sender }
      {
        auto-approve-level: auto-approve-level,
        notification-enabled: notification-enabled,
        data-retention-period: retention-period
      }
    ))
  )
)

;; Query functions
(define-read-only (get-kyc-status (user principal))
  (map-get? kyc-records { user: user })
)

(define-read-only (get-access-permission (user principal) (accessor principal))
  (match (map-get? kyc-permissions { user: user, accessor: accessor })
    permission 
      (if (and 
            (get granted permission)
            (< block-height (get expires-at permission)))
        (some permission)
        none)
    none
  )
)

(define-read-only (is-kyc-valid (user principal))
  (match (map-get? kyc-records { user: user })
    record 
      (and 
        (is-eq (get status record) KYC-VERIFIED)
        (< block-height (get expires-at record)))
    false
  )
)

(define-read-only (get-verification-level (user principal))
  (match (map-get? kyc-records { user: user })
    record 
      (if (is-kyc-valid user)
        (some (get verification-level record))
        none)
    none
  )
)

(define-read-only (can-access-kyc (user principal) (accessor principal) (required-level uint))
  (match (get-access-permission user accessor)
    permission (>= (get permission-level permission) required-level)
    false
  )
)

(define-read-only (get-user-preferences (user principal))
  (map-get? user-preferences { user: user })
)

(define-read-only (get-verifier-info (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

;; Utility functions
(define-public (update-kyc-expiry (user principal) (new-expiry uint))
  (let
    (
      (kyc-record (unwrap! (map-get? kyc-records { user: user }) ERR-NOT-FOUND))
      (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-UNAUTHORIZED))
    )
    (begin
      (asserts! (get authorized verifier-info) ERR-UNAUTHORIZED)
      (asserts! (is-eq (get status kyc-record) KYC-VERIFIED) ERR-INVALID-INPUT)
      
      (ok (map-set kyc-records
        { user: user }
        (merge kyc-record { expires-at: new-expiry })
      ))
    )
  )
)

(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER))
  )
)

;; Self-destruct function for user data (GDPR compliance)
(define-public (delete-my-data)
  (let
    (
      (kyc-record (unwrap! (map-get? kyc-records { user: tx-sender }) ERR-NOT-FOUND))
    )
    (begin
      ;; Delete KYC record
      (map-delete kyc-records { user: tx-sender })
      ;; Delete user preferences
      (map-delete user-preferences { user: tx-sender })
      (ok true)
    )
  )
)