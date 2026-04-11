#!/bin/sh
set -e

LIST="/work/fleet-sim/out/devices_top50.txt"
ACL="/work/fleet-sim/out/aclfile"

echo "# ACL Mosquitto — Fleet top50" > "$ACL"
echo "" >> "$ACL"


# Nettoyage de DEV pour éviter les retours à la ligne ou espaces
while IFS= read -r DEV || [ -n "$DEV" ]; do
  DEV="$(echo "$DEV" | tr -d '\r' | xargs)"
  [ -z "$DEV" ] && continue

  DEV_DNS="$(echo "$DEV" | tr '_' '-')"
  USER="${DEV_DNS}.iot.iot-pfe.local"
  echo "user $USER" >> "$ACL"
  echo "topic write iot/+/$(echo "$DEV")/#" >> "$ACL"
  echo "topic read  iot/commands/$DEV/#" >> "$ACL"
  echo "" >> "$ACL"
done < "$LIST"

echo "Wrote $ACL"