{{- with secret "secrets/infra/srv-26/technitium" -}}
TECHNITIUM_PASSWORD={{ .Data.data.password }}
{{- end }}
