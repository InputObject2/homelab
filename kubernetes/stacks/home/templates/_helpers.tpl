{{/*
Helpers for home stack
*/}}
{{- define "home.homeAssistantMqtt.hostname" -}}
{{- printf "%s.%s" .Values.homeAssistantMqtt.subdomain .Values.domain }}
{{- end }}