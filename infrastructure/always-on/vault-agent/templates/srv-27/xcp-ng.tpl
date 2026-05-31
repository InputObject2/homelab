{{- with secret "secrets/infra/srv-27/xcp-ng" -}}
XEN_HOST={{ .Data.data.host }}
XEN_USER={{ .Data.data.username }}
XEN_PASSWORD={{ .Data.data.password }}
XEN_SSL_VERIFY=false
XEN_MODE=pool
{{- end }}
