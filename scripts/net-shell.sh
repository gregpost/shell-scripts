#!/usr/bin/env bash
set -euo pipefail

NS="special-ns2"

# 1. Create the namespace
sudo ip netns add "$NS"

# 2. Bring up the loopback interface inside it
sudo ip netns exec "$NS" ip link set lo up

# (Optional) Move a network interface or configure veth here...
# sudo ip link add veth-host type veth peer name veth-ns
# sudo ip link set veth-ns netns "$NS"
# sudo ip link set veth-host up
# sudo ip netns exec "$NS" ip link set veth-ns up
# sudo ip netns exec "$NS" ip addr add 10.0.0.1/24 dev veth-ns

# 3. Launch an interactive bash shell inside the namespace
echo "Entering network namespace '$NS'. Type 'exit' to leave."
sudo ip netns exec "$NS" bash

