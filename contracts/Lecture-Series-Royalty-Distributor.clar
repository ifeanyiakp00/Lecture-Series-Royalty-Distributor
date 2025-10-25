(define-constant err-unauthorized u100)
(define-constant err-series-exists u101)
(define-constant err-series-not-found u102)
(define-constant err-invalid-share u103)
(define-constant err-no-recipients u104)
(define-constant err-zero-amount u105)
(define-constant err-duplicate-recipient u106)
(define-constant err-series-closed u107)
(define-constant err-length-mismatch u108)

(define-data-var next-series-id uint u1)

(define-map series-admin uint principal)
(define-map series-open uint bool)
(define-map series-total-shares uint uint)
(define-map series-recipient-shares {series: uint, recipient: principal} uint)

(define-read-only (series-exists (series uint))
  (is-some (map-get? series-admin series)))

(define-read-only (is-admin (series uint) (who principal))
  (match (map-get? series-admin series)
    admin (is-eq admin who)
    false))

(define-read-only (is-open (series uint))
  (default-to false (map-get? series-open series)))

(define-read-only (get-total-shares (series uint))
  (default-to u0 (map-get? series-total-shares series)))

(define-public (create-series)
  (let ((id (var-get next-series-id)))
    (if (series-exists id)
        (err err-series-exists)
        (begin
          (map-set series-admin id tx-sender)
          (map-set series-open id true)
          (map-set series-total-shares id u0)
          (var-set next-series-id (+ id u1))
          (ok id)))))

(define-public (set-series-admin (series uint) (new-admin principal))
  (if (and (series-exists series) (is-admin series tx-sender))
      (ok (map-set series-admin series new-admin))
      (err err-unauthorized)))

(define-public (close-series (series uint))
  (if (and (series-exists series) (is-admin series tx-sender))
      (ok (map-set series-open series false))
      (err err-unauthorized)))

(define-public (open-series (series uint))
  (if (and (series-exists series) (is-admin series tx-sender))
      (ok (map-set series-open series true))
      (err err-unauthorized)))

(define-read-only (get-series-admin (series uint))
  (map-get? series-admin series))

(define-read-only (get-series-open (series uint))
  (map-get? series-open series))

(define-read-only (get-series-total-shares (series uint))
  (map-get? series-total-shares series))

(define-read-only (get-share-of (series uint) (recipient principal))
  (map-get? series-recipient-shares {series: series, recipient: recipient}))

(define-public (add-recipient (series uint) (recipient principal) (shares uint))
  (if (and (series-exists series) 
           (is-admin series tx-sender) 
           (is-open series) 
           (> shares u0)
           (is-none (map-get? series-recipient-shares {series: series, recipient: recipient})))
      (let ((total (get-total-shares series)))
        (map-set series-recipient-shares {series: series, recipient: recipient} shares)
        (map-set series-total-shares series (+ total shares))
        (ok true))
      (err err-invalid-share)))

(define-public (remove-recipient (series uint) (recipient principal))
  (if (and (series-exists series) (is-admin series tx-sender) (is-open series))
      (match (map-get? series-recipient-shares {series: series, recipient: recipient})
        sh
          (let ((total (get-total-shares series)))
            (map-delete series-recipient-shares {series: series, recipient: recipient})
            (map-set series-total-shares series (- total sh))
            (ok true))
        (err err-series-not-found))
      (err err-unauthorized)))

(define-read-only (has-recipient (series uint) (recipient principal))
  (is-some (map-get? series-recipient-shares {series: series, recipient: recipient})))

(define-read-only (can-distribute (series uint))
  (let ((open (is-open series)) (total (get-total-shares series)))
    (and open (> total u0))))

(define-read-only (sum-shares (shares (list 200 uint)))
  (fold + shares u0))

(define-public (distribute (series uint) (amount uint) (recipients (list 200 principal)) (shares (list 200 uint)))
  (if (and (series-exists series)
           (is-open series)
           (> amount u0)
           (is-eq (len recipients) (len shares))
           (> (len recipients) u0)
           (is-eq (get-total-shares series) (sum-shares shares)))
      (ok true)
      (err err-invalid-share)))

(define-private (transfer-to-recipient (recipient principal) (amount uint))
  (stx-transfer? amount tx-sender recipient))

(define-private (calculate-portion (amount uint) (shares uint) (total-shares uint))
  (/ (* amount shares) total-shares))

(define-private (validate-recipient (series uint) (recipient principal) (expected-shares uint))
  (match (map-get? series-recipient-shares {series: series, recipient: recipient})
    actual-shares (is-eq actual-shares expected-shares)
    false))

(define-read-only (preview-distribution (series uint) (amount uint) (shares (list 200 uint)))
  (if (and (> amount u0) (> (get-total-shares series) u0))
      (let ((total (get-total-shares series)))
        (map calculate-portion 
             (list amount amount amount amount amount)
             shares
             (list total total total total total)))
      (list)))

(define-read-only (get-series-info (series uint))
  (if (series-exists series)
      (some {
        admin: (unwrap-panic (map-get? series-admin series)),
        open: (is-open series),
        total-shares: (get-total-shares series)
      })
      none))

(define-read-only (get-recipient-count (series uint))
  (get-total-shares series))

(define-private (is-valid-distribution (series uint) (recipients (list 200 principal)) (shares (list 200 uint)))
  (and (is-eq (len recipients) (len shares))
       (> (len recipients) u0)
       (is-eq (get-total-shares series) (sum-shares shares))))

(define-read-only (check-distribution (series uint) (amount uint) (recipients (list 200 principal)) (shares (list 200 uint)))
  (and (series-exists series)
       (is-open series)
       (> amount u0)
       (is-valid-distribution series recipients shares)))

(define-read-only (get-distribution-preview (series uint) (amount uint))
  (if (and (series-exists series) (> amount u0))
      (some {
        series: series,
        amount: amount,
        total-shares: (get-total-shares series),
        per-share: (if (> (get-total-shares series) u0)
                      (/ amount (get-total-shares series))
                      u0)
      })
      none))

(define-read-only (validate-distribution-data (series uint) (recipients (list 200 principal)) (shares (list 200 uint)))
  (and (series-exists series)
       (is-eq (len recipients) (len shares))
       (> (len recipients) u0)
       (is-eq (get-total-shares series) (sum-shares shares))))

(define-read-only (estimate-gas-cost (num-recipients uint))
  (* num-recipients u1000))

(define-read-only (get-contract-info)
  {
    version: "1.0.0",
    total-series: (- (var-get next-series-id) u1),
    contract-name: "Lecture-Series-Royalty-Distributor"
  })