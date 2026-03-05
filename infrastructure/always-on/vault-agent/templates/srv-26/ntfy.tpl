{{- with secret "secrets/infra/srv-26/ntfy" -}}
NTFY_AUTH_TOKEN={{ .Data.data.auth_token }}
{{- end }}
