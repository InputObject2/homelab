{{- with secret "secrets/infra/srv-28/zigbee2mqtt" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
