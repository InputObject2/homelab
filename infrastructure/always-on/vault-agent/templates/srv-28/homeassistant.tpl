{{- with secret "secrets/infra/srv-28/homeassistant" -}}
HA_API_TOKEN={{ .Data.data.api_token }}
HA_LATITUDE={{ .Data.data.latitude }}
HA_LONGITUDE={{ .Data.data.longitude }}
{{- end }}
