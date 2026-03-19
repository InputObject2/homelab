{{/*
Helpers for ai stack
*/}}
{{- define "ai.openWebui.hostname" -}}
{{- printf "%s.%s" .Values.openWebui.subdomain .Values.domain }}
{{- end }}