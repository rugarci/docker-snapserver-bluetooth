# docker-snapserver-bluetooth

[![](https://images.microbadger.com/badges/image/rugarci/snapserver-bluetooth.svg)](https://microbadger.com/images/rugarci/snapserver-bluetooth)

[![Docker Pulls](https://img.shields.io/docker/pulls/rugarci/snapserver-bluetooth.svg)](https://hub.docker.com/r/rugarci/snapserver-bluetooth/) 

Based on https://github.com/balenalabs/balena-sound/tree/master/bluetooth-audio

Tested on Raspberry pi 4


## Usage

For Docker compose

```yaml
  bt-sink:
    image: rugarci/snapserver-bluetooth
    network_mode: host
    privileged: true
    volumes:
      - btSinkVol:/var/cache/bluetooth
      - btSinkVol:/var/cache/snapcast
      - /run/dbus:/run/dbus

```
