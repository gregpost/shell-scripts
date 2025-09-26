#!/bin/bash
sudo wg-quick up wg1
ping -c 3 google.com
sleep 30
sudo wg-quick down wg1

