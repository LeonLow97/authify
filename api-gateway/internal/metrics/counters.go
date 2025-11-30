package metrics

import "github.com/prometheus/client_golang/prometheus"

// Prometheus Notes:
// Use CounterVec instead of Counter because it allows us to add labels to filter on Grafana

var (
	// Tracks number of requests (by method, path, status)
	HTTPRequests = prometheus.NewCounterVec(prometheus.CounterOpts{
		Name: "http_requests_total",
		Help: "Total number of HTTP requests",
	},
		[]string{Method, Path, Status},
	)

	// Tracks how long each request takes (p50/p90/p99)
	HTTPReqLatency = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "http_request_duration_seconds",
			Help:    "Duration of HTTP requests",
			Buckets: prometheus.DefBuckets,
		},
		[]string{Method, Path},
	)

	// Detects how many requests are currently being processed
	InFlightRequests = prometheus.NewGauge(prometheus.GaugeOpts{
		Name: "http_inflight_requests",
		Help: "Current number of in-flight HTTP requests",
	})
)
