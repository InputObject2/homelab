{{/*
Helpers for home stack
*/}}
{{- define "home.homeAssistantMqtt.hostname" -}}
{{- printf "%s.%s" .Values.homeAssistantMqtt.subdomain .Values.domain }}
{{- end }}

{{- define "home.homeAssistant.hostname" -}}
{{- printf "%s.%s" .Values.homeAssistant.subdomain .Values.domain }}
{{- end }}
