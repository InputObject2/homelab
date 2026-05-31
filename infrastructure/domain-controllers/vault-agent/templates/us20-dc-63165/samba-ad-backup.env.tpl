{{- with secret "secrets/infra/domain-controllers/s3" -}}
AWS_ACCESS_KEY_ID={{ .Data.data.access_key }}
AWS_SECRET_ACCESS_KEY={{ .Data.data.secret_key }}
S3_BUCKET={{ .Data.data.bucket }}
S3_ENDPOINT={{ .Data.data.endpoint }}
{{- end }}
