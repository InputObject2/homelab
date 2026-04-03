{{- with secret "secrets/infra/srv-26/technitium" -}}
DNS_SERVER_ADMIN_PASSWORD={{ .Data.data.password }}
{{- end }}
