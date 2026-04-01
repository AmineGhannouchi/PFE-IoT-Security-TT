#!/bin/sh
set -e

LIST="/work/fleet-sim/out/devices_top50.txt"
ACL="/work/fleet-sim/out/aclfile"

echo "# ACL Mosquitto — Fleet top50" > "$ACL"
echo "" >> "$ACL"

while IFS= read -r DEV; do
  [ -z "$DEV" ] && continue

  USER="${DEV}.iot.iot-pfe.local"
  echo "user $USER" >> "$ACL"
  echo "topic write iot/+/+$DEV/#" >> "$ACL"
  echo "topic read  iot/commands/$DEV/#" >> "$ACL"
  echo "" >> "$ACL"
done < "$LIST"

echo "Wrote $ACL"