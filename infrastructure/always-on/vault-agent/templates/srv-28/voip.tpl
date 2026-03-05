{{- with secret "secrets/infra/srv-28/freepbx" -}}
FREEPBX_ADMIN_PASSWORD={{ .Data.data.admin_password }}
FREEPBX_DB_PASSWORD={{ .Data.data.db_password }}
FREEPBX_SIP_PASSWORD={{ .Data.data.sip_password }}
{{- end }}
