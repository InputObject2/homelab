{{- with secret "secrets/infra/srv-28/mosquitto" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
