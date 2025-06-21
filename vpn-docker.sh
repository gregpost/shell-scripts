#!/bin/bash

docker load -i wireguard-test.tar

docker run -it --rm \
  --cap-add=NET_ADMIN \
  --device /dev/net/tun \
  --name wg-container \
  -v /data/gp/scripts:/shared \
  wireguard-test

