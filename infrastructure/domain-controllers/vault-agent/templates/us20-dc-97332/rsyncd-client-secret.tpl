{{- with secret "secrets/infra/domain-controllers/sysvol-sync" -}}
{{ .Data.data.password }}
{{- end }}
