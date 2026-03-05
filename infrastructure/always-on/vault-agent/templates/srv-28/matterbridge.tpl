{{- with secret "secrets/infra/srv-28/matterbridge" -}}
MATTERBRIDGE_IRC_PASSWORD={{ .Data.data.irc_password }}
MATTERBRIDGE_SLACK_TOKEN={{ .Data.data.slack_token }}
{{- end }}
