{{- with secret "secrets/infra/srv-27/observability" -}}
GRAFANA_ADMIN_PASSWORD={{ .Data.data.grafana_admin_password }}
PROMETHEUS_RETENTION={{ .Data.data.prometheus_retention }}
INFLUXDB_ADMIN_PASSWORD={{ .Data.data.influxdb_admin_password }}
{{- end }}
