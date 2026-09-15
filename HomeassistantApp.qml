import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

import FileIO 1.0

App {
    id: homeassistantApp

    property int debug: 0

    property url tileUrl : "HomeassistantTile.qml"
    property url thumbnailIcon: "drawables/homeAssistant.png"

    property HomeassistantConfigurationScreen homeAssistantConfigurationScreen
    property url homeAssistantConfigurationScreenUrl : "HomeassistantConfigurationScreen.qml"

    property HomeassistantScreen homeAssistantScreen
    property url homeAssistantScreenUrl : "HomeassistantScreen.qml"

    // --- connection ---
    property int connected : 0
    property string url : ""
    property string homeAssistantServer : ""
    property string homeAssistantSSL : "no"
    property string homeAssistantPort : "8123"
    property string homeAssistantToken : ""

    // --- tile options ---
    property int clockTile : 0

    // --- entity configuration (slot arrays, fixed length) ---
    property var sensorEntities : ["", "", "", "", "", "", "", ""]
    property var switchEntities : ["", "", "", "", ""]
    property var sceneEntities : ["", "", "", ""]
    property string alarmEntity : ""
    property string alarmCode : ""

    // --- fetched state: raw JSON per slot; always reassigned as a NEW array
    //     so bindings that read them re-evaluate (in-place mutation does not
    //     notify on this Qt5 build) ---
    property var sensorInfo : ["", "", "", "", "", "", "", ""]
    property var switchInfo : ["", "", "", "", ""]
    property var sceneInfo : ["", "", "", ""]
    property string alarmInfo : ""
    property string alarmState : ""

    // --- alarm dialpad ---
    property string alarmInputCode : ""
    property string alarmInputLabel : ""

    // --- clock shown on tile ---
    property string timeStr : ""
    property string dateStr : ""

    // --- debug log ---
    property string message : ""
    property bool logShown : false

    // --- polling bookkeeping ---
    property int pollGeneration : 0
    property int pollInFlight : 0

    FileIO {
        id: userSettingsFile
        source: "file:///mnt/data/tsc/homeassistant.userSettings.json"
    }

    FileIO {
        id: tokenFile
        source: "file:///mnt/data/tsc/homeassistant.token.txt"
    }

    //
    // Clock
    //

    function updateClockInfo() {
        var now = new Date().getTime();
        timeStr = i18n.dateTime(now, i18n.time_yes);
        dateStr = i18n.dateTime(now, i18n.mon_full);
    }

    Timer {
        id: clockTimer
        interval: 1000
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: updateClockInfo()
    }

    //
    // Polling: one timer drives both state refresh and re-check of the
    // connection while disconnected. Watchdog bounds a stuck fetch cycle
    // (xhr.timeout is unreliable on this Qt5 build).
    //

    Timer {
        id: refreshTimer
        interval: 60000
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: {
            if (homeassistantApp.connected) {
                homeassistantApp.startRefreshCycle();
            } else {
                homeassistantApp.checkConnection();
            }
        }
    }

    Timer {
        id: pollWatchdog
        interval: 20000
        repeat: false
        running: false
        onTriggered: {
            if (homeassistantApp.pollInFlight > 0) {
                homeassistantApp.pollInFlight = 0;
                homeassistantApp.pollGeneration = homeassistantApp.pollGeneration + 1;
                homeassistantApp.logText("Poll cycle timed out, callbacks from it are dropped");
            }
        }
    }

    function startRefreshCycle() {
        if (!connected || homeAssistantToken == "" || url == "") {
            return;
        }
        pollGeneration = pollGeneration + 1;
        var gen = pollGeneration;
        var i;

        for (i = 0; i < 8; i++) {
            if (sensorEntities[i] != "") {
                fetchState("sensor", i, sensorEntities[i], gen);
            }
        }
        for (i = 0; i < 5; i++) {
            if (switchEntities[i] != "") {
                fetchState("switch", i, switchEntities[i], gen);
            }
        }
        for (i = 0; i < 4; i++) {
            if (sceneEntities[i] != "") {
                fetchState("scene", i, sceneEntities[i], gen);
            }
        }
        if (alarmEntity != "") {
            fetchState("alarm", 0, alarmEntity, gen);
        }

        if (pollInFlight > 0) {
            pollWatchdog.restart();
        }
    }

    function fetchState(kind, index, entity, gen) {
        pollInFlight = pollInFlight + 1;
        apiGet("/api/states/" + entity, function (status, body) {
            pollInFlight = pollInFlight - 1;
            if (gen != pollGeneration) {
                return;
            }
            var payload = (status == 200) ? body : "";
            if (kind == "sensor") {
                setSlotArray("sensorInfo", index, payload);
            } else if (kind == "switch") {
                setSlotArray("switchInfo", index, payload);
            } else if (kind == "scene") {
                setSlotArray("sceneInfo", index, payload);
            } else {
                alarmInfo = payload;
                var state = stateOf(payload);
                if (state != "") {
                    alarmState = state;
                    // don't clobber the label while a code is being typed
                    if (!/\d$/.test(alarmInputLabel)) {
                        alarmInputLabel = state;
                    }
                }
            }
        });
    }

    function setSlotArray(prop, index, value) {
        var arr;
        if (prop == "sensorInfo") {
            arr = sensorInfo.slice();
        } else if (prop == "switchInfo") {
            arr = switchInfo.slice();
        } else {
            arr = sceneInfo.slice();
        }
        arr[index] = value;
        if (prop == "sensorInfo") {
            sensorInfo = arr;
        } else if (prop == "switchInfo") {
            switchInfo = arr;
        } else {
            sceneInfo = arr;
        }
    }

    function refreshNow() {
        if (connected) {
            startRefreshCycle();
        } else {
            checkConnection();
        }
    }

    //
    // HTTP layer. Home Assistant REST API (https://developers.home-assistant.io/docs/api/rest/)
    // authenticated with a long-lived access token; api_password auth was removed in
    // Home Assistant 2023.7 and is no longer supported here.
    //

    function apiGet(path, callback) {
        callApi("GET", path, "", callback);
    }

    function apiPost(path, payload, callback) {
        callApi("POST", path, payload, callback);
    }

    function callApi(method, path, payload, callback) {
        var http = new XMLHttpRequest();
        http.onreadystatechange = function () {
            if (http.readyState == 4) {
                callback(http.status, http.responseText);
            }
        };
        http.open(method, url + path, true);
        if (homeAssistantToken != "") {
            http.setRequestHeader("Authorization", "Bearer " + homeAssistantToken);
        }
        if (method == "POST") {
            http.setRequestHeader("Content-Type", "application/json");
        }
        http.send(payload);
    }

    function buildUrl() {
        var scheme = (homeAssistantSSL == "yes") ? "https://" : "http://";
        if (homeAssistantServer == "") {
            return "";
        }
        return scheme + homeAssistantServer + ":" + homeAssistantPort;
    }

    function readToken() {
        try {
            homeAssistantToken = tokenFile.read().trim();
        } catch (err) {
            homeAssistantToken = "";
        }
        if (homeAssistantToken == "") {
            logText("No access token found: create a long-lived token in your HA profile and save it to /mnt/data/tsc/homeassistant.token.txt");
        }
    }

    function checkConnection() {
        readToken();
        url = buildUrl();
        if (url == "") {
            connected = 0;
            return;
        }
        if (homeAssistantToken == "") {
            connected = 0;
            return;
        }
        apiGet("/api/", function (status, body) {
            if (status == 200) {
                if (!connected) {
                    logText("Connection established: " + body);
                }
                connected = 1;
                startRefreshCycle();
            } else {
                connected = 0;
                if (status == 401) {
                    logText("Connection refused: token rejected by " + url + " (HTTP 401)");
                } else {
                    logText("Could not reach Home Assistant at " + url + " (HTTP " + status + ")");
                }
            }
        });
    }

    //
    // Settings I/O: one file, built from a whitelist so no stray property can leak in.
    //

    function saveSettings() {
        var settings = {
            "Server": homeAssistantServer,
            "SSL": homeAssistantSSL,
            "Port": homeAssistantPort,
            "Clock": clockTile,
            "Sensors": sensorEntities.slice(),
            "Switches": switchEntities.slice(),
            "Scenes": sceneEntities.slice(),
            "Alarm": alarmEntity,
            "AlarmCode": alarmCode
        };
        var http = new XMLHttpRequest();
        http.open("PUT", "file:///mnt/data/tsc/homeassistant.userSettings.json");
        http.send(JSON.stringify(settings));
    }

    function paddedArray(value, length) {
        var out = [];
        var i;
        for (i = 0; i < length; i++) {
            var item = (value && value[i]) ? "" + value[i] : "";
            out.push(item.trim());
        }
        return out;
    }

    function readSettings() {
        var settings = {};
        try {
            settings = JSON.parse(userSettingsFile.read());
        } catch (err) {
            logText("No valid settings file yet, using defaults: " + err);
        }

        homeAssistantServer = settings.Server ? ("" + settings.Server).trim() : "";
        homeAssistantPort = settings.Port ? ("" + settings.Port).trim() : "8123";
        homeAssistantSSL = (settings.SSL == "yes") ? "yes" : "no";
        clockTile = settings.Clock ? 1 : 0;
        sensorEntities = paddedArray(settings.Sensors, 8);
        switchEntities = paddedArray(settings.Switches, 5);
        sceneEntities = paddedArray(settings.Scenes, 4);
        alarmEntity = settings.Alarm ? ("" + settings.Alarm).trim() : "";
        alarmCode = settings.AlarmCode ? "" + settings.AlarmCode : "";

        checkConnection();
    }

    // Called by the configuration screen when the user presses Opslaan.
    function saveConfiguration(server, port, ssl, clock, sensors, switches, scenes, alarmEntityId, alarmCodeValue) {
        homeAssistantServer = server.trim();
        if (/^[0-9]+$/.test(port.trim())) {
            homeAssistantPort = port.trim();
        }
        homeAssistantSSL = (ssl == "yes") ? "yes" : "no";
        clockTile = clock ? 1 : 0;
        sensorEntities = paddedArray(sensors, 8);
        switchEntities = paddedArray(switches, 5);
        sceneEntities = paddedArray(scenes, 4);
        alarmEntity = alarmEntityId.trim();
        alarmCode = alarmCodeValue;

        connected = 0;
        saveSettings();
        checkConnection();
    }

    //
    // State helpers: every QML binding goes through one of these so no file has to
    // JSON.parse (or try/catch, which is not valid inside a property binding).
    //

    function slotEntity(arr, index) {
        var value = arr[index];
        return (value === undefined || value === null) ? "" : value;
    }

    function sensorEntity(index) { return slotEntity(sensorEntities, index); }
    function switchEntity(index) { return slotEntity(switchEntities, index); }
    function sceneEntity(index) { return slotEntity(sceneEntities, index); }

    function stateOf(info) {
        if (!info) {
            return "";
        }
        try {
            var data = JSON.parse(info);
            return (data && data.state !== undefined) ? "" + data.state : "";
        } catch (err) {
            return "";
        }
    }

    function nameOf(info, entity) {
        if (info) {
            try {
                var data = JSON.parse(info);
                if (data && data.attributes && data.attributes.friendly_name) {
                    return "" + data.attributes.friendly_name;
                }
                if (data && data.entity_id) {
                    return tailOf("" + data.entity_id);
                }
            } catch (err) {
                // fall through to entity-based name
            }
        }
        return tailOf(entity);
    }

    function valueOf(info) {
        if (!info) {
            return "";
        }
        try {
            var data = JSON.parse(info);
            var state = "" + data.state;
            var unit = (data.attributes && data.attributes.unit_of_measurement) ? " " + data.attributes.unit_of_measurement : "";
            return state + unit;
        } catch (err) {
            return "";
        }
    }

    function tailOf(entity) {
        var dot = entity.indexOf(".");
        return (dot >= 0) ? entity.substring(dot + 1) : entity;
    }

    function sensorName(index) { return nameOf(sensorInfo[index], sensorEntities[index]); }
    function sensorValue(index) { return valueOf(sensorInfo[index]); }
    function switchName(index) { return nameOf(switchInfo[index], switchEntities[index]); }
    function sceneName(index) { return nameOf(sceneInfo[index], sceneEntities[index]); }

    function switchOn(index) {
        var state = stateOf(switchInfo[index]);
        return (state == "on" || state == "active" || state == "true");
    }

    //
    // Commands
    //

    function setEntity(entity, state) {
        if (!entity || entity == "") {
            return;
        }
        if (!connected) {
            logText("Not connected to Home Assistant, command not sent: " + entity);
            return;
        }
        if (homeAssistantToken == "") {
            logText("No access token, command not sent: " + entity);
            return;
        }

        var type = entity.indexOf(".") >= 0 ? entity.substring(0, entity.indexOf(".")) : entity;
        var service = "";
        var params = '{"entity_id": "' + entity + '"}';

        if (type == "scene") {
            service = "scene/turn_on";
        } else if (type == "switch" || type == "light" || type == "input_boolean" || type == "fan") {
            service = type + (state ? "/turn_on" : "/turn_off");
        } else if (type == "input_number") {
            service = "input_number/set_value";
            params = '{"entity_id": "' + entity + '", "value": "' + state + '"}';
        } else {
            logText("Unable to work with object type: " + type);
            return;
        }

        callApi("POST", "/api/services/" + service, params, function (status, body) {
            if (status != 200) {
                logText("Set FAILED for object: " + entity + ". Response Status: " + status);
            }
            startRefreshCycle();
        });
    }

    //
    // Alarm control panel
    //

    function alarmInput(num) {
        if (alarmInputCode.length >= 4) {
            return;
        }
        alarmInputCode = alarmInputCode + num;
        var masked = "";
        var i;
        for (i = 0; i < alarmInputCode.length - 1; i++) {
            masked = masked + "*";
        }
        alarmInputLabel = masked + num;
    }

    function alarmInputReset() {
        alarmInputCode = "";
        alarmInputLabel = alarmState;
    }

    function alarmToggle() {
        if (!connected || homeAssistantToken == "") {
            logText("Unable to send command. Please verify connection settings.");
            return;
        }
        // Mirror of the enter-button icon logic in HomeassistantScreen:
        // an "armed*" state disarms (typed code required), anything else arms
        // (with the configured code).
        if (alarmState.indexOf("armed") == 0) {
            if (alarmInputCode.length == 0) {
                logText("Enter the alarm code first");
                return;
            }
            callApi("POST", "/api/services/alarm_control_panel/alarm_disarm",
                    '{"entity_id": "' + alarmEntity + '", "code": "' + alarmInputCode + '"}',
                    function (status) {
                        if (status != 200) {
                            logText("Disarm FAILED, status: " + status);
                        }
                        alarmInputReset();
                        startRefreshCycle();
                    });
        } else {
            callApi("POST", "/api/services/alarm_control_panel/alarm_arm_away",
                    '{"entity_id": "' + alarmEntity + '", "code": "' + alarmCode + '"}',
                    function (status) {
                        if (status != 200) {
                            logText("Arm FAILED, status: " + status);
                        }
                        alarmInputReset();
                        startRefreshCycle();
                    });
        }
    }

    //
    // Debug log
    //

    function logText(log) {
        if (debug) {
            var d = new Date();
            var datetext = d.toTimeString().split(" ")[0];
            message = message + "\n[" + datetext + "." + d.getMilliseconds() + "] " + log;
            if (message.length > 6000) {
                message = message.slice(-5000);
            }
            logShown = true;
        }
    }

    //
    // Boot
    //

    function init() {
        registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Home Assistant"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
        registry.registerWidget("screen", homeAssistantConfigurationScreenUrl, this, "homeAssistantConfigurationScreen");
        registry.registerWidget("screen", homeAssistantScreenUrl, this, "homeAssistantScreen");
    }

    Component.onCompleted: {
        updateClockInfo();
        readSettings();
    }
}
