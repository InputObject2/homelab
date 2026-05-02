#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: discord-notifier.sh [OPTIONS]

  --webhook WEBHOOK              Discord webhook URL (required)
  --message MESSAGE              Simple text message
  --title TITLE                  Embed title
  --description DESC             Embed description
  --status [success|error|warning|info]
                                 Status type (determines color)
  --log-url URL                  URL to logs or pre-signed S3 URL
  --hostname HOSTNAME            Hostname to display
  --timestamp TIMESTAMP          Timestamp to display (default: now)
  --fields FIELD:VALUE,...       Comma-separated field:value pairs to add as embed fields
  --footer-text TEXT             Footer text
  --footer-icon-url URL          Footer icon URL

EOF
  exit 1
}

WEBHOOK=""
MESSAGE=""
TITLE=""
DESCRIPTION=""
STATUS="info"
LOG_URL=""
HOSTNAME="$(hostname)"
TIMESTAMP="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
FIELDS=""
FOOTER_TEXT=""
FOOTER_ICON_URL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webhook) WEBHOOK="$2"; shift 2 ;;
    --message) MESSAGE="$2"; shift 2 ;;
    --title) TITLE="$2"; shift 2 ;;
    --description) DESCRIPTION="$2"; shift 2 ;;
    --status) STATUS="$2"; shift 2 ;;
    --log-url) LOG_URL="$2"; shift 2 ;;
    --hostname) HOSTNAME="$2"; shift 2 ;;
    --timestamp) TIMESTAMP="$2"; shift 2 ;;
    --fields) FIELDS="$2"; shift 2 ;;
    --footer-text) FOOTER_TEXT="$2"; shift 2 ;;
    --footer-icon-url) FOOTER_ICON_URL="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; shift ;;
  esac
done

if [[ -z "$WEBHOOK" ]]; then
  echo "Error: --webhook is required" >&2
  usage
fi

# Determine color based on status
case "$STATUS" in
  success) COLOR=3066993 ;;   # Green
  error)   COLOR=15158332 ;;  # Red
  warning) COLOR=16776960 ;;  # Yellow
  info)    COLOR=3447003 ;;   # Blue
  *)       COLOR=9807270 ;;   # Gray
esac

# Build JSON payload safely using jq
if [[ -n "$TITLE" ]] || [[ -n "$DESCRIPTION" ]]; then
  # Use embed format — build with jq to handle special characters in values
  FIELDS_JSON='[
    {"name":"Hostname","value":null,"inline":true},
    {"name":"Status","value":null,"inline":true},
    {"name":"Timestamp","value":null,"inline":false}
  ]'
  FIELDS_JSON=$(jq -n \
    --arg hn "$HOSTNAME" \
    --arg st "$STATUS" \
    --arg ts "$TIMESTAMP" \
    '[
      {"name":"Hostname","value":$hn,"inline":true},
      {"name":"Status","value":$st,"inline":true},
      {"name":"Timestamp","value":$ts,"inline":false}
    ]')

  # Add custom fields if provided
  if [[ -n "$FIELDS" ]]; then
    IFS=',' read -r -a FIELD_ARRAY <<< "$FIELDS"
    for field in "${FIELD_ARRAY[@]}"; do
      IFS=':' read -r name value <<< "$field"
      FIELDS_JSON=$(echo "$FIELDS_JSON" | jq --arg n "$name" --arg v "$value" \
        '. += [{"name":$n,"value":$v,"inline":true}]')
    done
  fi

  # Add log URL as a field if provided
  if [[ -n "$LOG_URL" ]]; then
    FIELDS_JSON=$(echo "$FIELDS_JSON" | jq --arg url "$LOG_URL" \
      '. += [{"name":"Logs","value":("[Download Logs](" + $url + ")"),"inline":false}]')
  fi

  PAYLOAD=$(jq -n \
    --arg title "${TITLE:-Notification}" \
    --arg desc "${DESCRIPTION:-}" \
    --argjson color "$COLOR" \
    --argjson fields "$FIELDS_JSON" \
    --arg footer_text "$FOOTER_TEXT" \
    --arg footer_icon "$FOOTER_ICON_URL" \
    '{
      embeds: [{
        title: $title,
        description: $desc,
        color: $color,
        fields: $fields
      } + (if $footer_text != "" then {footer: ({text: $footer_text} + (if $footer_icon != "" then {icon_url: $footer_icon} else {} end))} else {} end)]
    }')
else
  # Simple message format
  PAYLOAD=$(jq -n --arg msg "${MESSAGE:-Notification}" '{"content":$msg}')
fi

# Send to Discord — capture HTTP status to detect silent failures
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "$PAYLOAD" \
  "$WEBHOOK")

if [[ "$HTTP_STATUS" == "204" ]]; then
  echo "Notification sent to Discord"
else
  echo "Discord notification failed (HTTP $HTTP_STATUS)" >&2
  exit 1
fi
