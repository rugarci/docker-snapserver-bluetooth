# docker-snapserver-bluetooth

[![Docker Pulls](https://img.shields.io/docker/pulls/rugarci/snapserver-bluetooth.svg)](https://hub.docker.com/r/rugarci/snapserver-bluetooth/)

Bluetooth speaker (A2DP sink) that feeds a [Snapcast](https://github.com/badaix/snapcast) server.
Pair an Alexa/Echo or a phone with it and the audio plays in every Snapcast room.

Originally based on [balena-sound bluetooth-audio](https://github.com/balenalabs/balena-sound/tree/master/bluetooth-audio).
Now built on `debian:trixie-slim` for `linux/arm64` (Raspberry Pi 3/4/5 with a 64-bit OS).

## How it works

- `bluealsa` (BlueALSA 4.3) registers an A2DP sink with the **host's** `bluetoothd` over D-Bus.
- `bluealsa-aplay` plays every incoming stream to the ALSA default device, which
  `/etc/asound.conf` resamples to 48 kHz / S16_LE and writes to `/var/cache/snapcast/snapfifo`.
- `bluetooth-agent` accepts pairings, names the adapter, hides it while a device is connected
  (or after the pairing window), and reconnects to the last audio device on start.

## Host requirements

- BlueZ running on the host with the `a2dp`/`media` plugins enabled (the default).
- The D-Bus policy for BlueALSA on the host, otherwise `bluealsa` cannot own `org.bluealsa`:

  ```bash
  sudo cp org.bluealsa.conf /etc/dbus-1/system.d/
  sudo systemctl reload dbus
  ```

- Snapserver with a pipe stream on the shared FIFO, e.g.
  `source = pipe:///tmp/bt-sink/snapfifo?name=Bluetooth&sampleformat=48000:16:2`.

## Usage

```yaml
  bt-sink:
    image: rugarci/snapserver-bluetooth
    restart: unless-stopped
    network_mode: host        # HCI management: class, LE off, PIN mode
    cap_add:
      - NET_ADMIN
    environment:
      - BLUETOOTH_DEVICE_NAME=Multiroom system
    volumes:
      - /run/dbus:/run/dbus
      - btSinkState:/var/cache/bluetooth
      - btSinkFifo:/var/cache/snapcast   # mounted by snapserver at /tmp/bt-sink
```

| Variable | Default | Meaning |
|---|---|---|
| `BLUETOOTH_DEVICE_NAME` | `BT-<hostname>` | Name shown to phones. |
| `BLUETOOTH_PIN_CODE` | (none) | 1-6 digit PIN. Switches to legacy pairing. Without it, pairing needs no confirmation. |
| `BLUETOOTH_HCI` | `hci0` | Adapter to use. |
| `BLUETOOTH_CLASSIC_ONLY` | `1` | Turn Bluetooth LE off while the container runs (back on when it stops). Amazon Echo devices do not list the speaker otherwise. |
| `BLUETOOTH_CLASS` | `0x240414` | Class of device written to the controller (Audio/Video loudspeaker with the Audio and Rendering service bits). Empty to leave BlueZ's. |
| `BLUETOOTH_PAIRING_WINDOW` | (none) | Seconds after start during which new devices can find and pair with the speaker (e.g. `300`). Afterwards it stays hidden and rejects pairings; paired devices still connect. Restart the container to pair a new device. Without it, the speaker is discoverable and pairable whenever no audio device is connected. |
| `SNAPCAST_TCP` | (none) | `host:port` of a Snapcast TCP source (`tcp://0.0.0.0:<port>?sampleformat=48000:16:2`) to send the audio to, for a snapserver on another machine. Without it, audio goes to the FIFO. |

Only devices with the A2DP Source profile count as connected: BLE links from other apps on the
same adapter neither hide the speaker nor replace the device to reconnect to. With
`BLUETOOTH_CLASSIC_ONLY=0` it can share the adapter with a BLE app (e.g. a BLE chat node), but a
BLE app that keeps scanning takes most of the radio time and the audio stutters (measured on a
Raspberry Pi 4); use a second Bluetooth adapter instead. Unless `BLUETOOTH_PAIRING_WINDOW` is
set, the adapter stays discoverable and pairable while no audio device is connected and accepts
every pairing without confirmation.
