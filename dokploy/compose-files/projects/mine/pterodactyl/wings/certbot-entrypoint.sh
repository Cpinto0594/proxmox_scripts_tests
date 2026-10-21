#!/bin/sh
set -e

DOMAIN="${DOMAIN:-wings.home.capilabs.dev}"
EMAIL="${CERTBOT_EMAIL:-admin@capilabs.dev}"

# Issue the cert once, if it doesn't already exist in the mounted
# /etc/letsencrypt volume.
if [ ! -d "/etc/letsencrypt/live/${DOMAIN}" ]; then
  certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    -d "${DOMAIN}" \
    --email "${EMAIL}" \
    --agree-tos \
    --non-interactive
fi

# Then just periodically ask certbot to renew — it only actually
# renews once inside its ~30-day-before-expiry window, so this is a
# cheap no-op most of the time.
while true; do
  certbot renew \
    --dns-cloudflare \
    --dns-cloudflare-credentials /etc/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 30 \
    --quiet
  sleep 12h
done
