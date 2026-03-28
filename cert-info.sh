#!/bin/bash

# Check if gum is installed
if command -v gum &> /dev/null; then
  USE_GUM=true
else
  USE_GUM=false
fi

# Check if a URL is provided
if [ -z "$1" ]; then
  if [ "$USE_GUM" = true ]; then
    gum style --border normal --margin "1" --padding "1 2" "Usage: $0 <url>"
  else
    echo "Usage: $0 <url>" >&2
  fi
  exit 1
fi

# Get the domain from the URL
domain=$(echo "$1" | awk -F/ '{print $3}')

# Get the certificate information
cert_info=$(echo | openssl s_client -servername "$domain" -connect "$domain":443 2>/dev/null | openssl x509 -noout -text)

# Get the expiration date and clean it
expire_date=$(echo "$cert_info" | grep "Not After" | cut -d: -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

# Calculate expiry epoch based on OS
if [[ "$(uname)" == "Darwin" ]]; then
  # macOS (BSD date)
  expire_epoch=$(date -j -f "%b %e %T %Y %Z" "$expire_date" "+%s")
else
  # Linux (GNU date)
  expire_epoch=$(date -d "$expire_date" +%s)
fi

now_epoch=$(date +%s)
days_left=$(( (expire_epoch - now_epoch) / 86400 ))

# Get other certificate details
issuer=$(echo "$cert_info" | grep "Issuer:" | sed 's/Issuer: //')
subject=$(echo "$cert_info" | grep "Subject:" | sed 's/Subject: //')
start_date=$(echo "$cert_info" | grep "Not Before" | cut -d: -f2- | sed 's/^[ \t]*//;s/[ \t]*$//')

# Create a formatted output
if [ "$USE_GUM" = true ]; then
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
  echo "Issuer: $issuer"
  echo "Subject: $subject"
  echo "Valid from: $start_date"
  echo "Valid until: $expire_date"
fi
