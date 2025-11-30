package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
)

var Registry = prometheus.NewRegistry()

func InitMetrics() {
	Registry.MustRegister(HTTPRequests)
	Registry.MustRegister(HTTPReqLatency)
	Registry.MustRegister(InFlightRequests)
	Registry.MustRegister(collectors.NewGoCollector())
	Registry.MustRegister(collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}))
}
