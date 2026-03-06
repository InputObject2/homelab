{{- with secret "secrets/infra/srv-26/github-runner" -}}
GITHUB_TOKEN={{ .Data.data.token }}
GITHUB_OWNER={{ .Data.data.owner }}
GITHUB_REPOSITORY={{ .Data.data.repository }}
{{- end }}
