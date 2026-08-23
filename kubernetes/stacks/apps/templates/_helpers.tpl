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
{{- define "apps.itop.hostname" -}}
{{- printf "%s.%s" .Values.itop.subdomain .Values.domain }}
{{- end }}
{{- define "apps.itop.image" -}}
{{- printf "%s.%s/inputobject2/itop" "docker-private-registry" .Values.domain }}
{{- end }}
{{- define "apps.n8n.hostname" -}}
{{- printf "%s.%s" .Values.n8n.subdomain .Values.domain }}
{{- end }}
{{- define "apps.forgejo.hostname" -}}
{{- printf "%s.%s" .Values.forgejo.subdomain .Values.domain }}
{{- end }}
{{- define "apps.forgejo.ssh_hostname" -}}
{{- printf "%s.%s" .Values.forgejo.ssh .Values.domain }}
{{- end }}
