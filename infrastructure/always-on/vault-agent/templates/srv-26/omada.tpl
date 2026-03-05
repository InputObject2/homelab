{{- with secret "secrets/infra/srv-26/omada" -}}
OMADA_ADMIN_PASSWORD={{ .Data.data.admin_password }}
{{- end }}
