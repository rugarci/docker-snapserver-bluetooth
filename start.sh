#!/usr/bin/env bash
# Start the BlueALSA A2DP sink, the pairing agent and the player that feeds Snapcast.
# If any of them exits, the container exits and Docker restarts it.
set -euo pipefail

HCI="${BLUETOOTH_HCI:-hci0}"
export BLUETOOTH_HCI="$HCI"
export DEVICE_NAME="${DEVICE_NAME:-${BLUETOOTH_DEVICE_NAME:-BT-$(hostname | cut -c -4)}}"

# Wait for the host's bluetoothd to expose the adapter
for _ in $(seq 30); do
  if dbus-send --system --print-reply --dest=org.bluez "/org/bluez/$HCI" \
       org.freedesktop.DBus.Properties.Get string:org.bluez.Adapter1 string:Address >/dev/null 2>&1; then
    break
  fi
  echo "Waiting for bluetoothd and $HCI..."
  sleep 2
done

# Run a btmgmt command. Without a TTY, btmgmt quits as soon as stdin hits EOF, often
# before the command is sent, and otherwise never exits: keep stdin open and bound it.
btmgmt_cmd() {
  sleep 3 | timeout 5 btmgmt --index "${HCI#hci}" "$@" >/dev/null 2>&1
  local rc=$?
  (( rc == 0 || rc == 124 ))
}

# Legacy PIN pairing needs Secure Simple Pairing disabled on the controller
# (requires network_mode: host and NET_ADMIN for the management socket).
pin="${BLUETOOTH_PIN_CODE:-}"
if [[ "$pin" =~ ^[0-9]{1,6}$ ]]; then
  echo "Legacy pairing mode, PIN code is \"$pin\""
  btmgmt_cmd ssp off || echo "WARNING: could not disable SSP" >&2
else
  # SSP is the controller default; nothing to change
  echo "Secure Simple Pairing mode (no PIN code)"
fi

mkdir -p /var/cache/bluetooth /var/cache/snapcast

# Optional: send the audio to a remote Snapcast TCP source (host:port) instead of the FIFO.
# The ALSA file plugin pipes into the command when the name starts with '|'.
if [[ -n "${SNAPCAST_TCP:-}" ]]; then
  echo "Sending audio to Snapcast TCP source $SNAPCAST_TCP"
  sed -i "s#^\(\s*file \).*#\1\"|exec nc -N ${SNAPCAST_TCP%:*} ${SNAPCAST_TCP##*:}\"#" /etc/asound.conf
else
  echo "Writing audio to /var/cache/snapcast/snapfifo"
fi

bluealsa -i "$HCI" -p a2dp-sink &
sleep 1
bluetooth-agent &
bluealsa-aplay --pcm-buffer-time=1000000 00:00:00:00:00:00 &
sleep 2

# Amazon Echo devices only list speakers that look like a classic one: BR/EDR only
# (no LE) and the class of a loudspeaker with the Audio service bit. BlueZ cannot set
# service bits, so write the class to the controller after the UUIDs are registered.
# Both need network_mode: host and NET_ADMIN. LE is turned back on when the container stops.
le_off=0
if [[ "${BLUETOOTH_CLASSIC_ONLY:-1}" == 1 ]]; then
  btmgmt_cmd le off || true
  le_off=1
  echo "Bluetooth LE disabled on $HCI (BR/EDR only)"
fi
if [[ -n "${BLUETOOTH_CLASS:-0x240414}" ]]; then
  hciconfig "$HCI" class "${BLUETOOTH_CLASS:-0x240414}" \
    && echo "Class of device set to ${BLUETOOTH_CLASS:-0x240414}" \
    || echo "WARNING: could not set the class of device" >&2
fi

cleanup() {
  kill $(jobs -p) 2>/dev/null || true
  wait 2>/dev/null || true
  if (( le_off )); then
    btmgmt_cmd le on || true
    echo "Bluetooth LE enabled again on $HCI"
  fi
}
trap 'cleanup; exit 0' TERM INT
wait -n
echo "A child process exited, stopping" >&2
cleanup
exit 1
