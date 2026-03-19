{{/*
Helpers for apps stack
*/}}
{{- define "apps.mealie.hostname" -}}
{{- printf "%s.%s" .Values.mealie.subdomain .Values.domain }}
{{- end }}
{{- define "apps.lubelogger.hostname" -}}
{{- printf "%s.%s" .Values.lubelogger.subdomain .Values.domain }}
{{- end }}
{{- define "apps.zammad.hostname" -}}
{{- printf "%s.%s" .Values.zammad.subdomain .Values.domain }}
{{- end }}
{{- define "apps.xenOrchestra.hostname" -}}
{{- printf "%s.%s" .Values.xenOrchestra.subdomain .Values.domain }}
{{- end }}