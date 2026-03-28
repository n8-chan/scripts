#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME=$(basename "$0")

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [OPTIONS] <url>

Check SSL/TLS certificate details for a given URL or domain.

Arguments:
  <url>         URL or domain to inspect (e.g. example.com or https://example.com)

Options:
  --url <url>   URL or domain (alternative to positional argument)
  --help        Show this help message and exit

Examples:
  $SCRIPT_NAME example.com
  $SCRIPT_NAME https://example.com
  $SCRIPT_NAME --url example.com
EOF
}

# Check if gum is installed
if command -v gum &>/dev/null; then
  USE_GUM=true
else
  USE_GUM=false
fi

# Parse arguments
URL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help | -h)
      usage
      exit 0
      ;;
    --url)
      shift
      URL="${1:-}"
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -z "$URL" ]]; then
        URL="$1"
      else
        echo "Error: unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      ;;
  esac
  shift
done

if [[ -z "$URL" ]]; then
  usage >&2
  exit 1
fi

# Ensure URL has a scheme so domain extraction works
if [[ "$URL" != http://* && "$URL" != https://* ]]; then
  URL="https://$URL"
fi

# Get the domain from the URL
domain=$(echo "$URL" | awk -F/ '{print $3}')

# Get the certificate information
cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | openssl x509 -noout -text)

if [[ -z "$cert_info" ]]; then
  echo "Error: could not retrieve certificate for $domain" >&2
  exit 1
fi

# Get the expiration date and clean it
expire_date=$(echo "$cert_info" | grep "Not After" | cut -d: -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

# Calculate expiry epoch based on OS
if [[ "$(uname)" == "Darwin" ]]; then
  expire_epoch=$(date -j -f "%b %e %T %Y %Z" "$expire_date" "+%s")
else
  expire_epoch=$(date -d "$expire_date" +%s)
fi

now_epoch=$(date +%s)
days_left=$(( (expire_epoch - now_epoch) / 86400 ))

# Get other certificate details
issuer=$(echo "$cert_info" | grep "Issuer:" | sed 's/.*Issuer: //')
subject=$(echo "$cert_info" | grep "Subject:" | sed 's/.*Subject: //')
start_date=$(echo "$cert_info" | grep "Not Before" | cut -d: -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

# Output formatted results
if [[ "$USE_GUM" == true ]]; then
  gum style \
    --border normal \
    --margin "1" \
    --padding "1 2" \
    "Certificate details for $(gum style --bold "$domain")" \
    "" \
    "$(gum style --bold "Days until expiry:") $days_left" \
    "$(gum style --bold "Issuer:") $issuer" \
    "$(gum style --bold "Subject:") $subject" \
    "$(gum style --bold "Valid from:") $start_date" \
    "$(gum style --bold "Valid until:") $expire_date"
else
  echo "Certificate details for: $domain"
  echo "----------------------------------------"
  echo "Days until expiry: $days_left"
  echo "Issuer:            $issuer"
  echo "Subject:           $subject"
  echo "Valid from:        $start_date"
  echo "Valid until:       $expire_date"
fi
