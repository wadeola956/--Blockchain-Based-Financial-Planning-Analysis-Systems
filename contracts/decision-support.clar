;; Decision Support Contract
;; Supports financial decisions with weighted scoring mechanisms

;; Constants
(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_DECISION_NOT_FOUND (err u501))
(define-constant ERR_CRITERIA_NOT_FOUND (err u502))
(define-constant ERR_INVALID_WEIGHT (err u503))
(define-constant ERR_INVALID_SCORE (err u504))

;; Data Variables
(define-data-var next-decision-id uint u1)
(define-data-var next-criteria-id uint u1)

;; Data Maps
(define-map decisions
  { decision-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    decision-type: (string-ascii 50),
    status: (string-ascii 20),
    final-score: uint,
    recommendation: (string-ascii 200),
    created-at: uint,
    updated-at: uint
  }
)

(define-map decision-criteria
  { criteria-id: uint }
  {
    decision-id: uint,
    criteria-name: (string-ascii 100),
    weight: uint,
    score: uint,
    weighted-score: uint,
    notes: (string-ascii 200)
  }
)

;; Public Functions

;; Create a new decision
(define-public (create-decision
  (title (string-ascii 100))
  (description (string-ascii 500))
  (decision-type (string-ascii 50))
)
  (let
    (
      (decision-id (var-get next-decision-id))
    )
    (map-set decisions
      { decision-id: decision-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        decision-type: decision-type,
        status: "draft",
        final-score: u0,
        recommendation: "",
        created-at: block-height,
        updated-at: block-height
      }
    )

    (var-set next-decision-id (+ decision-id u1))
    (ok decision-id)
  )
)

;; Add decision criteria
(define-public (add-decision-criteria
  (decision-id uint)
  (criteria-name (string-ascii 100))
  (weight uint)
  (score uint)
  (notes (string-ascii 200))
)
  (let
    (
      (criteria-id (var-get next-criteria-id))
      (weighted-score (* weight score))
    )
    (match (map-get? decisions { decision-id: decision-id })
      decision-data
      (begin
        (asserts! (is-eq (get creator decision-data) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (and (> weight u0) (<= weight u100)) ERR_INVALID_WEIGHT)
        (asserts! (and (>= score u0) (<= score u100)) ERR_INVALID_SCORE)

        (map-set decision-criteria
          { criteria-id: criteria-id }
          {
            decision-id: decision-id,
            criteria-name: criteria-name,
            weight: weight,
            score: score,
            weighted-score: weighted-score,
            notes: notes
          }
        )

        (var-set next-criteria-id (+ criteria-id u1))
        (ok criteria-id)
      )
      ERR_DECISION_NOT_FOUND
    )
  )
)

;; Update decision status and recommendation
(define-public (finalize-decision
  (decision-id uint)
  (final-score uint)
  (recommendation (string-ascii 200))
)
  (match (map-get? decisions { decision-id: decision-id })
    decision-data
    (begin
      (asserts! (is-eq (get creator decision-data) tx-sender) ERR_UNAUTHORIZED)
      (map-set decisions
        { decision-id: decision-id }
        (merge decision-data {
          status: "finalized",
          final-score: final-score,
          recommendation: recommendation,
          updated-at: block-height
        })
      )
      (ok true)
    )
    ERR_DECISION_NOT_FOUND
  )
)

;; Update criteria score
(define-public (update-criteria-score (criteria-id uint) (new-score uint))
  (match (map-get? decision-criteria { criteria-id: criteria-id })
    criteria-data
    (begin
      (match (map-get? decisions { decision-id: (get decision-id criteria-data) })
        decision-data
        (begin
          (asserts! (is-eq (get creator decision-data) tx-sender) ERR_UNAUTHORIZED)
          (asserts! (and (>= new-score u0) (<= new-score u100)) ERR_INVALID_SCORE)

          (let
            (
              (weight (get weight criteria-data))
              (new-weighted-score (* weight new-score))
            )
            (map-set decision-criteria
              { criteria-id: criteria-id }
              (merge criteria-data {
                score: new-score,
                weighted-score: new-weighted-score
              })
            )
            (ok true)
          )
        )
        ERR_DECISION_NOT_FOUND
      )
    )
    ERR_CRITERIA_NOT_FOUND
  )
)

;; Read-only Functions

;; Get decision by ID
(define-read-only (get-decision (decision-id uint))
  (map-get? decisions { decision-id: decision-id })
)

;; Get criteria by ID
(define-read-only (get-decision-criteria (criteria-id uint))
  (map-get? decision-criteria { criteria-id: criteria-id })
)

;; Get total decisions count
(define-read-only (get-total-decisions)
  (- (var-get next-decision-id) u1)
)

;; Get total criteria count
(define-read-only (get-total-criteria)
  (- (var-get next-criteria-id) u1)
)
