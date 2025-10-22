;; Credential Issuer Contract
;; Universities issue verifiable academic credentials

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CREDENTIAL-EXISTS (err u101))
(define-constant ERR-NOT-FOUND (err u102))
(define-constant ERR-REVOKED (err u103))

(define-data-var credential-counter uint u0)

;; Credentials
(define-map credentials
  { credential-id: uint }
  {
    holder: principal,
    issuer: principal,
    credential-type: (string-ascii 50),
    institution: (string-ascii 100),
    degree: (string-ascii 100),
    issue-date: uint,
    revoked: bool,
    metadata-hash: (string-ascii 64)
  }
)

;; Authorized issuers
(define-map issuers
  { issuer: principal }
  {
    authorized: bool,
    institution: (string-ascii 100),
    added-at: uint
  }
)

;; Holder credentials
(define-map holder-credentials
  { holder: principal, index: uint }
  { credential-id: uint }
)

(define-map holder-credential-count
  { holder: principal }
  { count: uint }
)

(define-private (is-issuer)
  (default-to false (get authorized (map-get? issuers { issuer: tx-sender })))
)

;; Issue credential
(define-public (issue-credential
    (holder principal)
    (credential-type (string-ascii 50))
    (degree (string-ascii 100))
    (metadata-hash (string-ascii 64))
  )
  (let
    (
      (new-id (+ (var-get credential-counter) u1))
      (issuer-info (unwrap! (map-get? issuers { issuer: tx-sender }) ERR-NOT-AUTHORIZED))
      (holder-count (default-to u0 (get count (map-get? holder-credential-count { holder: holder }))))
    )
    (asserts! (is-issuer) ERR-NOT-AUTHORIZED)
    (var-set credential-counter new-id)
    (map-set credentials
      { credential-id: new-id }
      {
        holder: holder,
        issuer: tx-sender,
        credential-type: credential-type,
        institution: (get institution issuer-info),
        degree: degree,
        issue-date: block-height,
        revoked: false,
        metadata-hash: metadata-hash
      }
    )
    (map-set holder-credentials
      { holder: holder, index: (+ holder-count u1) }
      { credential-id: new-id }
    )
    (map-set holder-credential-count
      { holder: holder }
      { count: (+ holder-count u1) }
    )
    (ok new-id)
  )
)

;; Revoke credential
(define-public (revoke-credential (credential-id uint))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get issuer credential)) ERR-NOT-AUTHORIZED)
    (map-set credentials
      { credential-id: credential-id }
      (merge credential { revoked: true })
    )
    (ok true)
  )
)

;; Add issuer
(define-public (add-issuer (issuer principal) (institution (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set issuers
      { issuer: issuer }
      {
        authorized: true,
        institution: institution,
        added-at: block-height
      }
    )
    (ok true)
  )
)

;; Verify credential
(define-read-only (verify-credential (credential-id uint))
  (match (map-get? credentials { credential-id: credential-id })
    credential (ok (not (get revoked credential)))
    (ok false)
  )
)

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials { credential-id: credential-id })
)

(define-read-only (get-holder-count (holder principal))
  (default-to u0 (get count (map-get? holder-credential-count { holder: holder })))
)

(define-read-only (get-holder-credential-by-index (holder principal) (index uint))
  (map-get? holder-credentials { holder: holder, index: index })
)

(define-read-only (get-issuer-info (issuer principal))
  (map-get? issuers { issuer: issuer })
)

(define-read-only (get-stats)
  (ok { total-credentials: (var-get credential-counter) })
)

;; Remove issuer authorization
(define-public (remove-issuer (issuer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set issuers
      { issuer: issuer }
      (merge (unwrap! (map-get? issuers { issuer: issuer }) ERR-NOT-FOUND) { authorized: false })
    )
    (ok true)
  )
)

;; Get all credentials for a holder
(define-read-only (get-all-holder-credentials (holder principal))
  (let
    (
      (count (get-holder-count holder))
    )
    (ok {
      holder: holder,
      total-credentials: count
    })
  )
)
