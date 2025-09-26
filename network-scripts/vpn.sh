#!/usr/bin/env bash
set -euo pipefail

NETNS="vpnns2"
WG_IFACE="wg1"
WG_CONF="/etc/wireguard/${WG_IFACE}.conf"
WG_ADDR="10.131.101.234/32"
DNS_SERVER="1.1.1.1"

cleanup() {
    ip netns del "$NETNS" &>/dev/null || true
}
trap cleanup EXIT

modprobe wireguard

if ip netns list | grep -qw "$NETNS"; then
    ip netns del "$NETNS"
fi

ip netns add "$NETNS"
ip link add "$WG_IFACE" type wireguard
ip link set "$WG_IFACE" netns "$NETNS"

# Configure wg manually (avoid wg setconf due to Address= line error)
PRIVATE_KEY="yO8RXIAene+bzOzNeMta13b5at8VLzF51+rgv6cNflA="
PEER_PUBLIC_KEY="TKG/e4HuJE4LWYw+JdNH9qbFabERrQJmYz5vgIop5Sk="
ENDPOINT="tr2.wg.finevpn.org:993"
ALLOWED_IPS="0.0.0.0/0"
KEEPALIVE="21"

ip netns exec "$NETNS" wg set "$WG_IFACE" \
    private-key <(echo "$PRIVATE_KEY") \
    peer "$PEER_PUBLIC_KEY" \
    endpoint "$ENDPOINT" \
    allowed-ips "$ALLOWED_IPS" \
    persistent-keepalive "$KEEPALIVE"

ip netns exec "$NETNS" ip address add "$WG_ADDR" dev "$WG_IFACE"
ip netns exec "$NETNS" ip link set dev "$WG_IFACE" up
ip netns exec "$NETNS" ip route add default dev "$WG_IFACE"
ip netns exec "$NETNS" bash -lc "echo 'nameserver ${DNS_SERVER}' > /etc/resolv.conf"
ip netns exec "$NETNS" bash --login

