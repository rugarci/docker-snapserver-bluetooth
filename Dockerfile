FROM debian:trixie-slim

# Bluetooth A2DP sink that writes the received audio into a Snapcast pipe.
# Uses the host's bluetoothd and system D-Bus (mount /run/dbus).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bluez \
      bluez-alsa-utils \
      netcat-openbsd \
      python3-dbus \
      python3-gi \
      tini \
 && rm -rf /var/lib/apt/lists/*

ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket \
    PYTHONUNBUFFERED=1

# ALSA default device: resample to 48 kHz/S16_LE and write to the Snapcast FIFO
COPY asound.conf /etc/asound.conf
COPY bluetooth-agent start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/bluetooth-agent /usr/local/bin/start.sh

# Last connected device, used to reconnect after a restart
VOLUME ["/var/cache/bluetooth"]

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["start.sh"]
