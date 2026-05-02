#!/usr/bin/env bash
set -euo pipefail

FILE=""
ENDPOINT=""
BUCKET=""
ACCESS_KEY=""
SECRET_KEY=""
EXPIRES=604800

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) FILE="$2"; shift 2 ;;
    --endpoint) ENDPOINT="$2"; shift 2 ;;
    --bucket) BUCKET="$2"; shift 2 ;;
    --access-key) ACCESS_KEY="$2"; shift 2 ;;
    --secret-key) SECRET_KEY="$2"; shift 2 ;;
    --expires) EXPIRES="$2"; shift 2 ;;
    *) shift ;;
  esac
done

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_EC2_METADATA_DISABLED=true

aws --endpoint-url "$ENDPOINT" s3 cp "$FILE" "s3://${BUCKET}/" >&2

PRESIGNED=$(aws --endpoint-url "$ENDPOINT" s3 presign "s3://${BUCKET}/$(basename "$FILE")" --expires-in "$EXPIRES")
echo "$PRESIGNED"
