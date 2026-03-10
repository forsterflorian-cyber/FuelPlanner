import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
using Toybox.Test;

class MockClock extends FuelClock {
    private var _now as Number = 0;

    function initialize(now as Number) {
        FuelClock.initialize();
        _now = now;
    }

    function now() as Number {
        return _now;
    }

    function setNow(now as Number) as Void {
        _now = now;
    }

    function advance(seconds as Number) as Number {
        _now += seconds;
        return _now;
    }
}

class MockMoment {
    private var _value as Number;

    function initialize(value as Number) {
        _value = value;
    }

    function value() as Number {
        return _value;
    }
}

class MockActivityInfo {
    public var timerTime as Number? = null;
    public var elapsedTime as Number? = null;
    public var timerState as Number? = null;
    public var startTime as MockMoment? = null;
    public var calories as Number? = null;
    public var energyExpenditure as Float? = null;

    function initialize(startTimestamp as Number?) {
        if (startTimestamp != null) {
            startTime = new MockMoment(startTimestamp);
        }
    }

    function setStartTimestamp(startTimestamp as Number?) as Void {
        startTime = (startTimestamp != null) ? new MockMoment(startTimestamp) : null;
    }

    function setTimerSeconds(seconds as Number) as Void {
        timerTime = seconds * 1000;
    }

    function setElapsedSeconds(seconds as Number) as Void {
        elapsedTime = seconds * 1000;
    }

    function advanceTimerSeconds(seconds as Number) as Void {
        if (timerTime == null) {
            timerTime = 0;
        }
        timerTime += seconds * 1000;
    }

    function setCalories(value as Number) as Void {
        calories = value;
    }

    function setEnergyExpenditure(value as Float) as Void {
        energyExpenditure = value;
    }
}

class MockSensorHistory {
    private var _samples as Array<Dictionary> = [] as Array<Dictionary>;

    function initialize() {
    }

    function addSample(timestamp as Number, value as Number) as Void {
        _samples.add({
            "t" => timestamp,
            "v" => value
        });
    }

    function size() as Number {
        return _samples.size();
    }

    function latest() as Dictionary? {
        if (_samples.size() <= 0) {
            return null;
        }
        return _samples[_samples.size() - 1];
    }
}

class MockStorageBackend extends StorageBackend {
    private var _values as Dictionary = {};

    function initialize() {
        StorageBackend.initialize();
    }

    function getValue(key as String) as Lang.Object? {
        return _values[key];
    }

    function setValue(key as String, value as Lang.Object?) as Void {
        _values[key] = value;
    }

    function deleteValue(key as String) as Void {
        try {
            _values.remove(key);
        } catch (e) {}
    }
}

class MockPropertiesBackend extends PropertiesBackend {
    private var _values as Dictionary = {};

    function initialize() {
        PropertiesBackend.initialize();
    }

    function getValue(key as String) as Lang.Object? {
        return _values[key];
    }

    function setValue(key as String, value as Lang.Object?) as Void {
        _values[key] = value;
    }
}

function boolToAscii(value as Boolean) as String {
    return value ? "true" : "false";
}

function absNumber(value as Number) as Number {
    return (value < 0) ? -value : value;
}

function buildFuelStatusLine(label as String, model as FuelModel) as String {
    return (
        label +
        " elapsedSec=" + model.getElapsedActiveSec().format("%d") +
        " targetG10=" + model.getTargetTotalG10().format("%d") +
        " consumedG10=" + model.getConsumedTotalG10().format("%d") +
        " deficitG10=" + model.getDeficitG10().format("%d") +
        " nextDueSec=" + model.getNextDueInSec().format("%d") +
        " displayNextDueSec=" + model.getDisplayNextDueInSec().format("%d") +
        " reminderDue=" + boolToAscii(model.isReminderDue()) +
        " gaugeTone=" + FuelPlannerFieldView.getGaugeAlertTone(model.getDeficitG10())
    );
}

function logFuelStatus(logger as Test.Logger, label as String, model as FuelModel) as Void {
    logger.debug(buildFuelStatusLine(label, model));
}

function printFuelStatus(label as String, model as FuelModel) as Void {
    System.println(buildFuelStatusLine(label, model));
}

function captureMemoryStats() as Dictionary {
    var stats = System.getSystemStats();
    var usedMemory = stats.usedMemory;
    var totalMemory = stats.totalMemory;
    return {
        "usedMemory" => usedMemory,
        "totalMemory" => totalMemory,
        "freeMemory" => totalMemory - usedMemory
    };
}

function formatMemoryStats(label as String, stats as Dictionary) as String {
    return (
        label +
        " usedMemory=" + (stats["usedMemory"] as Number).format("%d") +
        " totalMemory=" + (stats["totalMemory"] as Number).format("%d") +
        " freeMemory=" + (stats["freeMemory"] as Number).format("%d")
    );
}

function printMemoryStats(label as String) as Dictionary {
    var stats = captureMemoryStats();
    System.println(formatMemoryStats(label, stats));
    return stats;
}

function churnTemporaryAllocations(rounds as Number) as Void {
    for (var i = 0; i < rounds; i += 1) {
        var scratch = [] as Array<Dictionary>;
        for (var j = 0; j < 8; j += 1) {
            scratch.add({
                "round" => i,
                "slot" => j
            });
        }
    }
}

function sampleSettledMemory(label as String, samples as Number) as Dictionary {
    var best = captureMemoryStats();
    var totalSamples = (samples <= 0) ? 1 : (samples * 4);
    for (var i = 0; i < totalSamples; i += 1) {
        churnTemporaryAllocations(4);
        var current = captureMemoryStats();
        if ((current["usedMemory"] as Number) < (best["usedMemory"] as Number)) {
            best = current;
        }
    }
    System.println(formatMemoryStats(label, best));
    return best;
}

function createRenderSurface(width as Number, height as Number) as Dictionary? {
    try {
        if (Graphics has :createBufferedBitmap) {
            var bufferRef = Graphics.createBufferedBitmap({
                :width => width,
                :height => height
            });
            var bufferedBitmap = bufferRef.get() as Graphics.BufferedBitmap;
            if (bufferedBitmap != null) {
                return {
                    "bitmap" => bufferedBitmap,
                    "dc" => bufferedBitmap.getDc()
                };
            }
        }
    } catch (e) {}

    try {
        var fallbackBitmap = new Graphics.BufferedBitmap({
            :width => width,
            :height => height
        });
        return {
            "bitmap" => fallbackBitmap,
            "dc" => fallbackBitmap.getDc()
        };
    } catch (e) {}

    return null;
}

function simulateCrash(storageBackend as MockStorageBackend,
                       props as MockPropertiesBackend,
                       now as Number) as Dictionary {
    var crashClock = new MockClock(now);
    var restoredStorage = new StorageManager(storageBackend, props);
    var restoredModel = new FuelModel(restoredStorage, crashClock);
    restoredModel.setTouchForTest(true);
    restoredModel.loadSession();
    return {
        "clock" => crashClock,
        "storage" => restoredStorage,
        "model" => restoredModel
    };
}
