{{- with secret "secrets/infra/srv-26/tailscale" -}}
TS_AUTHKEY={{ .Data.data.authkey }}
{{- end }}
