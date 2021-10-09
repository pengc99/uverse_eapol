#!/bin/bash
#Start EAP-TLS on eth2 - check your interface names
#Check if already running to avoid multiple instances

IF_WAN=eth2
PROCESS_NAME=wpa_supplicant
PROCESS_PATH=/config/scripts/wpa_supplicant
PROCESS_COUNT=$(ps -A | grep -c $PROCESS_NAME)

if [ $PROCESS_COUNT = 0 ] && [ -x $PROCESS_PATH ]; then
        $PROCESS_PATH -s -B -Dwired -i$IF_WAN -c/config/scripts/wpa_supplicant.conf -g/var/run/wpa_supplicant.ctrl -P/var/run/wpa_supplicant.pid
fi
