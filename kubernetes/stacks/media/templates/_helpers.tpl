{{/*
Helpers for media stack
*/}}
{{- define "media.immich.hostname" -}}
{{- printf "%s.%s" .Values.immich.subdomain .Values.domain }}
{{- end }}
{{- define "media.gaseous.hostname" -}}
{{- printf "%s.%s" .Values.gaseous.subdomain .Values.domain }}
{{- end }}