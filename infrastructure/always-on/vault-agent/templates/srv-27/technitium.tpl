{{- with secret "secrets/infra/srv-27/technitium" -}}
TECHNITIUM_PASSWORD={{ .Data.data.password }}
{{- end }}
