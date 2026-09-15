# Toon Home Assistant App

A QML app for the [Toon smart thermostat](https://www.quby.com/) that shows Home Assistant sensors on the home tile and lets you run scenes, toggle switches and arm/disarm an alarm from the Toon screen. Distributed as `apps.homeassistant`.

This is a rewritten fork of the [ToonSoftwareCollective/homeassistant](https://github.com/ToonSoftwareCollective/homeassistant) app (tag `upstream-1.0.8` marks the original code), rebuilt to current Home Assistant API and Toon app standards.

## Features

- Up to 8 sensors on a tile (with optional clock) and in the app screen
- Up to 4 scene buttons and 5 switch/toggle entities (`switch`, `light`, `input_boolean`, `fan`)
- Alarm control panel with on-screen code dialpad (arm away / disarm)
- Settings screens for server, port, SSL, clock tile and all entity ids
- Works on Toon 1 and Toon 2/NXT (800x480 and 400x240)

## Prerequisites

A Home Assistant instance reachable from your Toon over the LAN. The app talks to the standard [REST API](https://developers.home-assistant.io/docs/api/rest/) (default port 8123) using a **long-lived access token**:

1. In Home Assistant, open your profile (bottom left) → scroll to **Long-Lived Access Tokens** → *Create Token*.
2. Copy the token and store it in the file `/mnt/data/tsc/homeassistant.token.txt` on the Toon (the whole token on one line, no quotes).

```bash
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip>
echo 'PASTE_YOUR_TOKEN_HERE' > /mnt/data/tsc/homeassistant.token.txt
```

The legacy `api_password` authentication is **not supported** (it was removed in Home Assistant 2023.7). If you use HTTPS with a self-signed certificate, requests will fail — the Toon's Qt build does not accept unknown CAs; use a trusted certificate or plain HTTP on your LAN.

## Installation

The Toon's old SSH server needs legacy options (`-O` because the device has no sftp-server, `ssh-rsa` for the host key). Icons live in `drawables/` and must be deployed alongside the QML:

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml qmldir drawables root@<toon-ip>:/qmf/qml/apps/homeassistant/
```

To apply changes, restart the Toon GUI (this restarts all apps):

```bash
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

Add the tile from the Toon widget picker (general category). In the app, *Instellingen* opens the configuration screens: connection (server, port, SSL, clock) and one page per entity group. Fill entity ids like `sensor.temperature_woning` or `switch.sonos_plug`; leave slots empty to hide them. *Opslaan* writes the settings and checks the connection; the back button discards changes.

## Configuration

Settings are stored at `/mnt/data/tsc/homeassistant.userSettings.json`:

| Key | Meaning |
|---|---|
| `Server` | IP or hostname of Home Assistant |
| `Port` | API port (default 8123) |
| `SSL` | `"yes"` to use https |
| `Clock` | 1 = show clock on tile |
| `Sensors` / `Switches` / `Scenes` | entity id arrays (8 / 5 / 4 slots) |
| `Alarm` | `alarm_control_panel` entity id |
| `AlarmCode` | code sent when arming (stored plaintext, like the HA app convention) |

State is polled every 60 seconds and on every manual interaction; while disconnected the same timer retries the connection.

## Version

Current version: **2.0.0** — see [Changelog.txt](Changelog.txt) for full history.
