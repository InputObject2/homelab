{{- with secret "secrets/infra/srv-26/gatus" -}}
GATUS_DISCORD_WEBHOOK={{ .Data.data.discord_webhook }}
{{- end }}
