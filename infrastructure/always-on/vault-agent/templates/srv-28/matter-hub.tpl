{{- with secret "secrets/infra/srv-28/matter-hub" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
