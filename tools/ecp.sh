#!/usr/bin/env bash
# Control the Roku TV over its External Control Protocol (port 8060, LAN only).
#
#   ROKU_IP=192.168.1.50 tools/ecp.sh dashboard    open the dashboard channel
#   ROKU_IP=192.168.1.50 tools/ecp.sh apps         list installed channels and their ids
#   ROKU_IP=192.168.1.50 tools/ecp.sh launch 12    launch a channel by id (12 = Netflix)
#   ROKU_IP=192.168.1.50 tools/ecp.sh key Home     press a remote key (Home, Select, Up, PowerOff, ...)
#
# ECP must be allowed on the TV: Settings > System > Advanced system settings >
# Control by mobile apps > Network access = Default or Permissive.
set -euo pipefail

: "${ROKU_IP:?set ROKU_IP to the TV IP address}"
base="http://${ROKU_IP}:8060"

case "${1:-}" in
    dashboard) curl -fsS -d '' "${base}/launch/dev" ;;
    apps)      curl -fsS "${base}/query/apps" ;;
    launch)    curl -fsS -d '' "${base}/launch/${2:?channel id}" ;;
    key)       curl -fsS -d '' "${base}/keypress/${2:?key name}" ;;
    *)         sed -n '2,10p' "$0"; exit 1 ;;
esac
