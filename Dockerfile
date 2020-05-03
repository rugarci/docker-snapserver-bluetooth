FROM balenalib/raspberrypi3-debian:stretch
#FROM balenalib/armv7hf-alpine


ENV DBUS_SYSTEM_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket
ENV UDEV=1

#RUN  apt-get update

#RUN apk --update --upgrade add \
#RUN  apt-get install -y \
RUN install_packages \
  alsa-utils \
  bluealsa \
  bluez \ 
  python-dbus \
  python-gobject \
  python-gpiozero

# Copy sounds
COPY sounds /usr/src/sounds

# Setup udev rules - this lets us play the connect/disconnect sound,
# turn off discover/pairing when a client is connected
# and also run a python script
COPY bluetooth-udev /usr/src/
RUN chmod +x /usr/src/bluetooth-udev
COPY udev-rules/ /etc/udev/rules.d/
COPY bluetooth-scripts/ /usr/src/bluetooth-scripts/

# Bluetooth-agent handles the auth of devices
COPY bluetooth-agent /usr/src/
RUN chmod +x /usr/src/bluetooth-agent

COPY start.sh /usr/src/
RUN chmod +x /usr/src/start.sh

COPY .asoundrc /root/.asoundrc

CMD [ "/bin/bash", "/usr/src/start.sh" ]

