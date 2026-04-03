{{- with secret "secrets/infra/srv-27/technitium" -}}
DNS_SERVER_ADMIN_PASSWORD={{ .Data.data.password }}
{{- end }}
