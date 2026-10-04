#!/bin/bash
# Task A: this Mac's network details for the IP/service table.
# Finds the Wi-Fi interface name itself (it is NOT always en0).
DEV=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}')

echo "== Hardware ports: the Wi-Fi entry shows our interface (Device) and MAC (Ethernet Address)"
networksetup -listallhardwareports | grep -A2 "Hardware Port: Wi-Fi"
echo
echo "== Wi-Fi settings: IP address, subnet mask, gateway (Router), MAC (Wi-Fi ID)"
networksetup -getinfo Wi-Fi | grep -E "^IP address|^Subnet mask|^Router|^Wi-Fi ID"
echo
echo "== Interface $DEV: MAC in use (ether) and IP + netmask (inet)"
ifconfig "$DEV" | grep -E "ether |inet "
echo
echo "== Default route: gateway and interface"
route -n get default | grep -E "gateway|interface"
echo
MASK=$(networksetup -getinfo Wi-Fi | awk -F': ' '/^Subnet mask/{print $2}')
PREFIX=$(echo "$MASK" | awk -F. '{n=0; for(i=1;i<=4;i++){x=$i; while(x>0){n+=x%2; x=int(x/2)}} print n}')
echo "SUMMARY  interface=$DEV  ip=$(ipconfig getifaddr "$DEV")  mask=$MASK (= /$PREFIX)"
