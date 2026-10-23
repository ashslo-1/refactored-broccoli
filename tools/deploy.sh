#!/usr/bin/env bash
# Build the channel and sideload it onto a Roku in developer mode.
#
#   ROKU_IP=192.168.1.50 ROKU_PASS=yourdevpassword tools/deploy.sh
#
# The password is the one you set when enabling developer mode. The upload
# replaces whatever dev channel is installed (Roku allows one at a time).
set -euo pipefail

: "${ROKU_IP:?set ROKU_IP to the TV IP address}"
: "${ROKU_PASS:?set ROKU_PASS to the developer mode password}"

cd "$(dirname "$0")/../channel"
npm run build
curl --fail --silent --show-error --user "rokudev:${ROKU_PASS}" --digest \
    -F "mysubmit=Install" -F "archive=@dist/rokumio-client.zip" \
    "http://${ROKU_IP}/plugin_install" | grep -o "Install Success\|Identical to previous version" || {
    echo "Upload finished but the TV did not report success; check http://${ROKU_IP} in a browser." >&2
    exit 1
}
