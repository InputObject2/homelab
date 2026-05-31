{{- with secret "secrets/infra/domain-controllers/sysvol-sync" -}}
rsync:{{ .Data.data.password }}
{{- end }}
