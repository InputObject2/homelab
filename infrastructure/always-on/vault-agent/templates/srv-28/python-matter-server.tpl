{{- with secret "secrets/infra/srv-28/python-matter-server" -}}
{{- range $k, $v := .Data.data }}
{{ $k }}={{ $v }}
{{- end }}
{{- end }}
