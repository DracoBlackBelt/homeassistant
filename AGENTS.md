# AGENTS.md

Compact guide for OpenCode sessions. This is the canonical agent file; `CLAUDE.md` and `GEMINI.md` only point here.

## What this is

QML app for the Toon smart thermostat (module `apps.homeassistant`). Shows Home Assistant sensors on the tile and controls scenes / switches / an alarm control panel through the HA REST API with a long-lived access token. Rewritten fork of ToonSoftwareCollective/homeassistant (git tag `upstream-1.0.8` = original code; diff against it for upstream comparison). No build step, no tests, no linter, no CI. Like `sonos/`, this folder **is** its own git repo (public on DracoBlackBelt's GitHub; don't commit unless asked).

## Deploy / verify

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml qmldir drawables root@<toon-ip>:/qmf/qml/apps/homeassistant/
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

`-O` (no sftp-server on device) and `+ssh-rsa` (old host key) are both required. Device dir is **unversioned** and icons use relative `drawables/...` paths, so `drawables/` must sit next to the QML. No local way to run QML (the `qb.*`/`FileIO`/`BasicUIControls` modules only exist on the device). Static verification with the Qt6 install on the PC (Homebrew): `qmllint *.qml` — expect 0 *Error*s; the import/`Unqualified access`/`onShown` warnings are all the missing device modules and are also present for the known-working sonos files, so only new errors matter. `qmlformat <file> > /dev/null` (nonzero stderr = parse failure) and brace-extracted `node` checks of the pure helpers are the remaining pre-deploy checks.

## Home Assistant connection model (since 2.0.0 — upstream-era docs are wrong)

- Token-only auth: `Authorization: Bearer <token>` against `http(s)://<server>:<port>/api/...`. The long-lived token lives in `/mnt/data/tsc/homeassistant.token.txt`; **never write/overwrite this file from the app** (upstream truncated it to empty on read failure — don't reintroduce). `api_password` / `x-ha-access` / `?api_password=` are gone (removed in HA 2023.7); there is no Legacy switch anymore and no `Pass` setting.
- All HTTP goes through `apiGet`/`apiPost` → `callApi(method, path, payload, cb)` with `cb(status, body)`; `JSON.parse` never happens outside app-side try/catch helpers.
- Polling: `refreshTimer` (60 s, repeat) → `startRefreshCycle()` while connected, else `checkConnection()` (doubles as reconnect); `refreshNow()` is the same branch used by screen `onShown` and the logo-tap manual refresh. A cycle stamps `pollGeneration`; stale callbacks from superseded/timed-out cycles are dropped (`fetchState` gen check); `pollWatchdog` (20 s) frees `pollInFlight` if XHRs stall — `xhr.timeout` is unreliable on this Qt build, the watchdog is the real bound.
- `setEntity(entity, state)` whitelists domains: `scene` (turn_on), `switch`/`light`/`input_boolean`/`fan` (turn_on/turn_off), `input_number` (set_value). Anything else logs and no-ops. The old 6-button "slider" widget was removed; `input_number` only works via direct API use.
- Alarm: `alarmToggle()` — when state starts with `armed`, disarms (`alarm_disarm` + dialpad-typed `alarmInputCode`, required); anything else arms (`alarm_arm_away` + configured `AlarmCode`). This mirrors the enter-button icon condition (`indexOf("armed") == 0` → locked) — keep both in sync. Dialpad caps at 4 digits; `alarmInputLabel` masking must not be clobbered by state updates while typing (`/\d$/` check in `fetchState`).

## Non-obvious code facts

- **Slot arrays, never in-place mutation.** Entities and fetched state are fixed-length `property var` arrays (`sensorEntities`/`sensorInfo`, `switchEntities`/`switchInfo`, `sceneEntities`/`sceneInfo`). UI reads them only through app helper functions (`sensorName(i)`, `sensorValue(i)`, `switchOn(i)`, `slotEntity(...)`) — bindings re-evaluate because helpers read the array property AND the app always replaces it via `setSlotArray()` (slice → mutate → reassign). Writing `arr[i] = x` in place silently no-ops notifications on this Qt5 build.
- `try/catch` is NOT valid inside a QML property binding (upstream had ~40 such bindings, all broken). Keep parsing in App functions; screens bind to `app.xxx(i)` calls only. Screens must never be dereferenced from the App's async callbacks (boot-time callbacks used to crash on `homeAssistantScreen.switch1R...` before the screen existed) — the App holds state, screens read it.
- `ToggleSwitch.qml` (`checked` + `toggled()`): the widget NEVER writes its own `checked` property — a JS write would destroy the external binding, which is the source of upstream's inverted switch images. Optimistic UI is intentionally out: the next refresh confirms. `ToggleBlock.qml` = label + ToggleSwitch for the config screen; both are same-dir implicit types (like sonos delegates), not in qmldir.
- `HomeassistantConfigurationScreen` edits **drafts** (`draftSensors` etc., copied `onShown`); only *Opslaan* pushes via `app.saveConfiguration(...)`, which saves settings FIRST and then `checkConnection()` (upstream persisted only as a callback side-effect). Back button discards.
- Settings: single file `/mnt/data/tsc/homeassistant.userSettings.json` (keys: `Server, Port, SSL, Clock, Sensors[], Switches[], Scenes[], Alarm, AlarmCode`), read via `FileIO` with defaults on parse failure (port falls back to 8123), written via XHR PUT built from a whitelist. The pre-2.0 side-files (`homeassistant.sensors.json` etc.) are NOT read and NOT migrated.
- Layout: all three screens compute metrics from `isNxt` via small metric properties (`pad/gap/rowH/...` on the screen root) and use anchors + Column/Row/Grid/Repeater so Toon 1 (400x240) collapses instead of clipping. No absolute pixel positions from the 800x480 upstream layout.
- `EditTextLabel4421.qml` is the workspace-wide shared input-widget copy (identical to sonos/calender/buienradar) — mirror changes there, don't dedupe.
- Debug: set `debug: 1` on the App root; `logText()` fills `message`/`logShown`, the main screen shows a dismissable overlay. `message` is capped at ~6 k chars.

## Platform rules (apply to every file here)

- **ES5 only** — Qt5 JavaScriptCore: `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 methods.
- **No fetch API** — all HTTP and file writes via `XMLHttpRequest`.
- UI strings are Dutch, wrapped in `qsTr()`; `lang/*.ts` match the current strings and the shipped `lang/*.qm` are compiled from them with the PC-side Qt6 `lrelease lang/*.ts` (Qt 6.11 message format still loads on the device's Qt5). Re-run `lrelease` in the same commit whenever a `qsTr()` string is added, changed or removed — a stale `.qm` silently shows the Dutch source instead.
- Colors in dimmable contexts (tile): `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X`.
- Widget registration lives in `function init()`; `Component.onCompleted` only calls `updateClockInfo()` + `readSettings()`.

## Releases

Bump `version.txt` (currently `2.0.0`) and prepend a brief block to `Changelog.txt` together when changing behavior.
