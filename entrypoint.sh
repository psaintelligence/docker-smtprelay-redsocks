#!/bin/bash

set -e

export REDSOCKS_TARGET_IP="${REDSOCKS_TARGET_IP:-socks-proxy}"
export REDSOCKS_TARGET_PORT="${REDSOCKS_TARGET_PORT:-1080}"
export REDSOCKS_TARGET_TYPE="${REDSOCKS_TARGET_TYPE:-socks5}"

stderr() {
    echo "$@" >&2
}

# Test the redsocks target exists and is reachable
if ! ping -c 1 -W 5 ${REDSOCKS_TARGET_IP} >/dev/null 2>&1; then
    stderr "ERROR: Redsocks target host \"${REDSOCKS_TARGET_IP}\" is unreachable"
    exit 1
fi

# Test that NET_ADMIN capability is available
if ip link add test_dummy type dummy 2>/dev/null; then
    ip link delete test_dummy
else
    stderr "ERROR: Container requires --cap-add=NET_ADMIN to manage iptables."
    exit 1
fi

# Apply iptables redirect on outbound SMTP protocols
iptables -t nat -A OUTPUT -p tcp --dport 25 -j REDIRECT --to-port 1080
iptables -t nat -A OUTPUT -p tcp --dport 465 -j REDIRECT --to-port 1080
iptables -t nat -A OUTPUT -p tcp --dport 587 -j REDIRECT --to-port 1080

# Create /etc/redsocks.conf from template and start redsocks in background
envsubst < /etc/redsocks-template.conf > /etc/redsocks.conf
redsocks &
__REDSOCKS_PID=$!

# Start smtprelay in background
/usr/local/bin/smtprelay "${@}" &
__SMTPRELAY_PID=$!

# Catch either background process going to exit
trap "kill -TERM $__REDSOCKS_PID $__SMTPRELAY_PID 2>/dev/null; exit 0" SIGTERM SIGINT
wait -n
stderr "ERROR: terminating"
exit 1
