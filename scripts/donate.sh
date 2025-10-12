#!/usr/bin/env bash
# Hyper-NixOS - Donate / Support Menu
# Presents donation/support options and opens links if possible

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" || {
  echo "ERROR: Failed to load common library" >&2
  exit 1
}

init_logging "donate"

# Defaults (override via /etc/hypervisor/config.json → .donate)
SPONSORS_URL="https://github.com/sponsors/MasterofNull"
KO_FI_URL="https://ko-fi.com/masterofnull"
PAYPAL_URL="https://paypal.me/masterofnull"
STRIPE_URL="https://buy.stripe.com/REPLACE_LINK"
README_URL="https://github.com/MasterofNull/Hyper-NixOS#-support--donations"

# Load optional donation links from config.json if present and enabled
if [[ -f "$HYPERVISOR_CONFIG" ]] && jq -e '.donate? != null' "$HYPERVISOR_CONFIG" >/dev/null 2>&1; then
  enabled=$(json_get "$HYPERVISOR_CONFIG" '.donate.enable' "true")
  if [[ "$enabled" == "true" || "$enabled" == "True" ]]; then
    SPONSORS_URL=$(json_get "$HYPERVISOR_CONFIG" '.donate.github_sponsors' "$SPONSORS_URL")
    KO_FI_URL=$(json_get "$HYPERVISOR_CONFIG" '.donate.ko_fi' "$KO_FI_URL")
    PAYPAL_URL=$(json_get "$HYPERVISOR_CONFIG" '.donate.paypal' "$PAYPAL_URL")
    STRIPE_URL=$(json_get "$HYPERVISOR_CONFIG" '.donate.stripe' "$STRIPE_URL")
    README_URL=$(json_get "$HYPERVISOR_CONFIG" '.donate.readme' "$README_URL")
  else
    $DIALOG --msgbox "Donations are disabled by configuration." 8 50
    exit 0
  fi
fi

open_url() {
  local url="$1"
  log_info "Opening donation URL: $url"
  if command -v xdg-open >/dev/null 2>&1; then
    nohup xdg-open "$url" >/dev/null 2>&1 &
    $DIALOG --msgbox "Opened in your default browser:\n\n$url" 10 70
  elif command -v sensible-browser >/dev/null 2>&1; then
    nohup sensible-browser "$url" >/dev/null 2>&1 &
    $DIALOG --msgbox "Opened in your browser:\n\n$url" 10 70
  elif command -v w3m >/dev/null 2>&1; then
    w3m "$url" || true
  elif command -v links >/dev/null 2>&1; then
    links "$url" || true
  else
    $DIALOG --msgbox "Please open this link manually:\n\n$url" 12 70
  fi
}

copy_all_links() {
  local all_links
  all_links="GitHub Sponsors: $SPONSORS_URL\nKo-fi: $KO_FI_URL\nPayPal: $PAYPAL_URL\nStripe: $STRIPE_URL\nREADME: $README_URL"
  if command -v xclip >/dev/null 2>&1; then
    printf "%s" "$all_links" | xclip -selection clipboard
    $DIALOG --msgbox "Copied donation links to clipboard." 8 50
  else
    $DIALOG --msgbox "Donation links:\n\n$all_links" 18 70
  fi
}

main_menu() {
  local choice
  choice=$($DIALOG --title "Support Development" --menu "Choose an option" 18 78 10 \
    1 "❤ GitHub Sponsors (0% platform fees)" \
    2 "☕ Ko-fi (one-time tip)" \
    3 "💳 PayPal (donate)" \
    4 "⚡ Stripe (payment link)" \
    5 "ℹ README (all options)" \
    "" "" \
    9 "Copy all links" \
    99 "← Back to Main Menu" \
    3>&1 1>&2 2>&3 || echo 99)

  case "$choice" in
    1) open_url "$SPONSORS_URL" ;;
    2) open_url "$KO_FI_URL" ;;
    3) open_url "$PAYPAL_URL" ;;
    4) open_url "$STRIPE_URL" ;;
    5) open_url "$README_URL" ;;
    9) copy_all_links ;;
    99|*) return 0 ;;
  esac
}

while true; do
  main_menu || break
done
