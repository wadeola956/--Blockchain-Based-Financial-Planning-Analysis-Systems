;; Forecasting Coordination Contract
;; Coordinates financial forecasting activities

;; Constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_FORECAST_NOT_FOUND (err u201))
(define-constant ERR_INVALID_STATUS (err u202))
(define-constant ERR_INVALID_TIMELINE (err u203))

;; Data Variables
(define-data-var next-forecast-id uint u1)

;; Data Maps
(define-map forecasts
  { forecast-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    forecast-type: (string-ascii 50),
    start-period: uint,
    end-period: uint,
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint
  }
)

(define-map forecast-data
  { forecast-id: uint, period: uint }
  {
    revenue: uint,
    expenses: uint,
    profit: int,
    confidence: uint
  }
)

;; Public Functions

;; Create a new forecast
(define-public (create-forecast
  (title (string-ascii 100))
  (description (string-ascii 500))
  (forecast-type (string-ascii 50))
  (start-period uint)
  (end-period uint)
)
  (let
    (
      (forecast-id (var-get next-forecast-id))
      (caller tx-sender)
    )
    (asserts! (> end-period start-period) ERR_INVALID_TIMELINE)

    (map-set forecasts
      { forecast-id: forecast-id }
      {
        creator: caller,
        title: title,
        description: description,
        forecast-type: forecast-type,
        start-period: start-period,
        end-period: end-period,
        status: "draft",
        created-at: block-height,
        updated-at: block-height
      }
    )

    (var-set next-forecast-id (+ forecast-id u1))
    (ok forecast-id)
  )
)

;; Add forecast data for a specific period
(define-public (add-forecast-data
  (forecast-id uint)
  (period uint)
  (revenue uint)
  (expenses uint)
  (confidence uint)
)
  (let
    (
      (profit (- (to-int revenue) (to-int expenses)))
    )
    (match (map-get? forecasts { forecast-id: forecast-id })
      forecast-info
      (begin
        (asserts! (is-eq (get creator forecast-info) tx-sender) ERR_UNAUTHORIZED)
        (asserts! (and (>= period (get start-period forecast-info))
              (<= period (get end-period forecast-info))) ERR_INVALID_TIMELINE)

        (map-set forecast-data
          { forecast-id: forecast-id, period: period }
          {
            revenue: revenue,
            expenses: expenses,
            profit: profit,
            confidence: confidence
          }
        )
        (ok true)
      )
      ERR_FORECAST_NOT_FOUND
    )
  )
)

;; Update forecast status
(define-public (update-forecast-status (forecast-id uint) (new-status (string-ascii 20)))
  (match (map-get? forecasts { forecast-id: forecast-id })
    forecast-info
    (begin
      (asserts! (is-eq (get creator forecast-info) tx-sender) ERR_UNAUTHORIZED)
      (map-set forecasts
        { forecast-id: forecast-id }
        (merge forecast-info { status: new-status, updated-at: block-height })
      )
      (ok true)
    )
    ERR_FORECAST_NOT_FOUND
  )
)

;; Read-only Functions

;; Get forecast by ID
(define-read-only (get-forecast (forecast-id uint))
  (map-get? forecasts { forecast-id: forecast-id })
)

;; Get forecast data for specific period
(define-read-only (get-forecast-data (forecast-id uint) (period uint))
  (map-get? forecast-data { forecast-id: forecast-id, period: period })
)

;; Get total forecasts count
(define-read-only (get-total-forecasts)
  (- (var-get next-forecast-id) u1)
)
