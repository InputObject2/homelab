{{- with secret "secrets/infra/srv-28/esphome" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
