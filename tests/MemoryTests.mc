using Toybox.Test;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

const MEMORY_CACHE_TOLERANCE_BYTES = 512;
const FR955_RENDER_WIDTH = 260;
const FR955_FULL_RENDER_HEIGHT = 260;
const FR955_COMPACT_RENDER_HEIGHT = 64;

class ForcedReminderManager extends ReminderManager {
    private var _triggerCount as Number = 0;

    function initialize() {
        ReminderManager.initialize();
    }

    function triggerReminder() as Boolean {
        _triggerCount += 1;
        return true;
    }

    function triggerAutoIntake() as Boolean {
        return true;
    }

    function getTriggerCount() as Number {
        return _triggerCount;
    }
}

class SilentReminderManager extends ReminderManager {
    function initialize() {
        ReminderManager.initialize();
    }

    function triggerReminder() as Boolean {
        return false;
    }

    function triggerAutoIntake() as Boolean {
        return false;
    }
}

class TestFuelPlannerFieldView extends FuelPlannerFieldView {
    function initialize(model as FuelModel, reminder as ReminderManager) {
        FuelPlannerFieldView.initialize(model, reminder);
    }

    function computeWithMock(info) as Void {
        compute(info);
    }
}

class MemoryTests {
    static function buildContext(now as Number) as Dictionary {
        var clock = new MockClock(now);
        var props = new MockPropertiesBackend();
        var storageBackend = new MockStorageBackend();
        var storage = new StorageManager(storageBackend, props);
        var model = new FuelModel(storage, clock);
        model.setTouchForTest(true);
        return {
            "clock" => clock,
            "props" => props,
            "storage" => storage,
            "model" => model
        };
    }

    static function applyDefaults(props as MockPropertiesBackend,
                                  model as FuelModel) as Void {
        props.setValue("carbsTargetGph", 60);
        props.setValue("doseG", 25);
        props.setValue("startDelayMin", 0);
        props.setValue("maxSnoozeMin", 5);
        props.setValue("reminderMode", 0);
        props.setValue("carbFractionPct", 60);
        model.onSettingsChanged();
    }

    static function updatePeak(currentStats as Dictionary,
                               peakUsed as Number,
                               totalMemory as Number) as Dictionary {
        var currentUsed = currentStats["usedMemory"] as Number;
        var currentTotal = currentStats["totalMemory"] as Number;

        if (currentUsed > peakUsed) {
            peakUsed = currentUsed;
        }
        if (currentTotal > totalMemory) {
            totalMemory = currentTotal;
        }

        return {
            "peakUsed" => peakUsed,
            "totalMemory" => totalMemory
        };
    }

    static function invokeViewCompute(view as TestFuelPlannerFieldView,
                                      info as MockActivityInfo) as Void {
        view.computeWithMock(info);
    }

    static function createRenderSurface(width as Number,
                                        height as Number) as Graphics.BufferedBitmap {
        return Graphics.createBufferedBitmap({
            :width => width,
            :height => height,
            :palette => [
                Graphics.COLOR_BLACK,
                Graphics.COLOR_WHITE,
                Graphics.COLOR_RED,
                Graphics.COLOR_YELLOW,
                Graphics.COLOR_GREEN,
                Graphics.COLOR_DK_GREEN,
                Graphics.COLOR_DK_RED,
                Graphics.COLOR_ORANGE,
                Graphics.COLOR_LT_GRAY,
                Graphics.COLOR_DK_GRAY
            ]
        }).get() as Graphics.BufferedBitmap;
    }

    static function renderViewOnSurface(view as TestFuelPlannerFieldView,
                                        surface as Graphics.BufferedBitmap,
                                        expectedWidth as Number,
                                        expectedHeight as Number) as Boolean {
        var dc = surface.getDc();
        view.onLayout(dc);
        view.onUpdate(dc);
        return dc.getWidth() == expectedWidth && dc.getHeight() == expectedHeight;
    }

    static function warmMemoryPaths() as Void {
        var ctx = buildContext(50);
        var storage = ctx["storage"] as StorageManager;
        var props = ctx["props"] as MockPropertiesBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaults(props, model);

        var info = new MockActivityInfo(50);
        info.setTimerSeconds(60);
        model.compute(info);

        var menu = new FuelPlannerMenu(storage, null);
        var delegate = new FuelPlannerMenuDelegate(storage, menu, null);
        var reminder = new SilentReminderManager();
        var view = new TestFuelPlannerFieldView(model, reminder);
        invokeViewCompute(view, info);

        System.println("memory_warmup complete=true delegateLive=" + boolToAscii(delegate != null));
    }

    static function runMenuAndBookingLoop() as Dictionary {
        var ctx = buildContext(1000);
        var clock = ctx["clock"] as MockClock;
        var props = ctx["props"] as MockPropertiesBackend;
        var storage = ctx["storage"] as StorageManager;
        var model = ctx["model"] as FuelModel;
        applyDefaults(props, model);

        var info = new MockActivityInfo(1000);
        info.setTimerSeconds(60);
        model.compute(info);

        var peak = updatePeak(printMemoryStats("loop_live_start"), 0, 0);
        for (var i = 0; i < 50; i += 1) {
            var menu = new FuelPlannerMenu(storage, null);
            var delegate = new FuelPlannerMenuDelegate(storage, menu, null);

            clock.advance(1);
            model.recordDefaultIntake();
            clock.advance(1);
            model.recordDefaultIntake();

            info.setTimerSeconds(60 + ((i + 1) * 30));
            model.compute(info);

            if ((i % 10) == 0 || i == 49) {
                printFuelStatus("loop_iter_" + i.format("%d"), model);
                System.println("loop_delegate_" + i.format("%d") + " live=" + boolToAscii(delegate != null));
                peak = updatePeak(
                    printMemoryStats("loop_mem_" + i.format("%d")),
                    peak["peakUsed"] as Number,
                    peak["totalMemory"] as Number
                );
            }

            menu = null;
            delegate = null;
        }

        var endStats = printMemoryStats("loop_live_end");
        peak = updatePeak(
            endStats,
            peak["peakUsed"] as Number,
            peak["totalMemory"] as Number
        );

        return {
            "peakUsed" => peak["peakUsed"],
            "totalMemory" => peak["totalMemory"],
            "intakeCount" => model.getIntakeCount(),
            "consumedG10" => model.getConsumedTotalG10()
        };
    }

    static function measurePeakLoad() as Dictionary {
        var ctx = buildContext(9000);
        var props = ctx["props"] as MockPropertiesBackend;
        var storage = ctx["storage"] as StorageManager;
        var model = ctx["model"] as FuelModel;
        applyDefaults(props, model);
        props.setValue("carbsTargetGph", 120);
        model.onSettingsChanged();

        var reminder = new ForcedReminderManager();
        var view = new TestFuelPlannerFieldView(model, reminder);
        var menu = new FuelPlannerMenu(storage, null);
        var delegate = new FuelPlannerMenuDelegate(storage, menu, null);

        var peak = updatePeak(printMemoryStats("peak_before_compute"), 0, 0);

        var info = new MockActivityInfo(9000);
        info.setTimerSeconds(1800);
        invokeViewCompute(view, info);
        printFuelStatus("peak_after_compute", model);
        peak = updatePeak(
            printMemoryStats("peak_after_compute"),
            peak["peakUsed"] as Number,
            peak["totalMemory"] as Number
        );

        var fullSurface = createRenderSurface(FR955_RENDER_WIDTH, FR955_FULL_RENDER_HEIGHT);
        var fullSurfaceReady = renderViewOnSurface(
            view,
            fullSurface,
            FR955_RENDER_WIDTH,
            FR955_FULL_RENDER_HEIGHT
        );
        peak = updatePeak(
            printMemoryStats("peak_after_full_render"),
            peak["peakUsed"] as Number,
            peak["totalMemory"] as Number
        );

        var compactSurface = createRenderSurface(FR955_RENDER_WIDTH, FR955_COMPACT_RENDER_HEIGHT);
        var compactSurfaceReady = renderViewOnSurface(
            view,
            compactSurface,
            FR955_RENDER_WIDTH,
            FR955_COMPACT_RENDER_HEIGHT
        );
        peak = updatePeak(
            printMemoryStats("peak_after_compact_render"),
            peak["peakUsed"] as Number,
            peak["totalMemory"] as Number
        );
        System.println(
            "peak_render fullReady=" + boolToAscii(fullSurfaceReady) +
            " compactReady=" + boolToAscii(compactSurfaceReady) +
            " tone=" + model.getRingTone().format("%d")
        );

        System.println(
            "peak_summary triggerCount=" + reminder.getTriggerCount().format("%d") +
            " delegateLive=" + boolToAscii(delegate != null)
        );

        return {
            "surfaceReady" => fullSurfaceReady && compactSurfaceReady,
            "peakUsed" => peak["peakUsed"],
            "totalMemory" => peak["totalMemory"],
            "triggerCount" => reminder.getTriggerCount()
        };
    }

    static function measureRenderCleanup() as Dictionary {
        var ctx = buildContext(12000);
        var clock = ctx["clock"] as MockClock;
        var props = ctx["props"] as MockPropertiesBackend;
        var model = ctx["model"] as FuelModel;
        applyDefaults(props, model);

        var reminder = new SilentReminderManager();
        var view = new TestFuelPlannerFieldView(model, reminder);

        var info = new MockActivityInfo(12000);
        info.setTimerSeconds(900);

        invokeViewCompute(view, info);

        var fullSurface = createRenderSurface(FR955_RENDER_WIDTH, FR955_FULL_RENDER_HEIGHT);
        var compactSurface = createRenderSurface(FR955_RENDER_WIDTH, FR955_COMPACT_RENDER_HEIGHT);
        var renderDc = fullSurface.getDc();
        view.onLayout(renderDc);
        view.onUpdate(renderDc);
        var surfacesReady = renderDc.getWidth() == FR955_RENDER_WIDTH &&
                            renderDc.getHeight() == FR955_FULL_RENDER_HEIGHT;
        renderDc = compactSurface.getDc();
        view.onLayout(renderDc);
        view.onUpdate(renderDc);
        surfacesReady = renderDc.getWidth() == FR955_RENDER_WIDTH &&
                        renderDc.getHeight() == FR955_COMPACT_RENDER_HEIGHT &&
                        surfacesReady;

        var baselineStats = sampleSettledMemory("render_baseline", 6);
        var peak = updatePeak(
            baselineStats,
            baselineStats["usedMemory"] as Number,
            baselineStats["totalMemory"] as Number
        );

        for (var i = 0; i < 40; i += 1) {
            clock.advance(5);
            info.setTimerSeconds(905 + (i * 5));
            invokeViewCompute(view, info);
            var frameWidth = FR955_RENDER_WIDTH;
            var frameHeight = FR955_FULL_RENDER_HEIGHT;
            if ((i % 2) == 0) {
                renderDc = fullSurface.getDc();
                view.onLayout(renderDc);
                view.onUpdate(renderDc);
                surfacesReady = renderDc.getWidth() == FR955_RENDER_WIDTH &&
                                renderDc.getHeight() == FR955_FULL_RENDER_HEIGHT &&
                                surfacesReady;
            } else {
                frameHeight = FR955_COMPACT_RENDER_HEIGHT;
                renderDc = compactSurface.getDc();
                view.onLayout(renderDc);
                view.onUpdate(renderDc);
                surfacesReady = renderDc.getWidth() == FR955_RENDER_WIDTH &&
                                renderDc.getHeight() == FR955_COMPACT_RENDER_HEIGHT &&
                                surfacesReady;
            }

            if ((i % 10) == 0 || i == 39) {
                printFuelStatus("render_frame_" + i.format("%d"), model);
                System.println(
                    "render_frame_" + i.format("%d") +
                    " width=" + frameWidth.format("%d") +
                    " height=" + frameHeight.format("%d") +
                    " tone=" + model.getRingTone().format("%d")
                );
                peak = updatePeak(
                    printMemoryStats("render_mem_" + i.format("%d")),
                    peak["peakUsed"] as Number,
                    peak["totalMemory"] as Number
                );
            }
        }

        var afterStats = sampleSettledMemory("render_after", 6);
        peak = updatePeak(
            afterStats,
            peak["peakUsed"] as Number,
            peak["totalMemory"] as Number
        );

        return {
            "surfaceReady" => surfacesReady,
            "baselineUsed" => baselineStats["usedMemory"],
            "afterUsed" => afterStats["usedMemory"],
            "peakUsed" => peak["peakUsed"]
        };
    }

    (:test)
    static function menuAndBookingLoopReturnsToBaseline(logger as Test.Logger) as Boolean {
        warmMemoryPaths();

        var baselineStats = sampleSettledMemory("loop_baseline", 6);
        var loopResult = runMenuAndBookingLoop();
        var afterStats = sampleSettledMemory("loop_after", 6);
        var delta = absNumber(
            (afterStats["usedMemory"] as Number) -
            (baselineStats["usedMemory"] as Number)
        );

        System.println(
            "loop_summary baselineUsed=" + (baselineStats["usedMemory"] as Number).format("%d") +
            " afterUsed=" + (afterStats["usedMemory"] as Number).format("%d") +
            " delta=" + delta.format("%d") +
            " tolerance=" + MEMORY_CACHE_TOLERANCE_BYTES.format("%d") +
            " peakUsed=" + (loopResult["peakUsed"] as Number).format("%d") +
            " intakeCount=" + (loopResult["intakeCount"] as Number).format("%d")
        );

        Test.assertMessage(loopResult["intakeCount"] as Number == 100, "The stress loop must simulate exactly 100 gel bookings.");
        Test.assertEqual(100, loopResult["intakeCount"] as Number);
        Test.assertMessage(delta <= MEMORY_CACHE_TOLERANCE_BYTES, "Menu open/close plus 100 bookings must stay within the observed simulator cache floor of 512 bytes.");
        return true;
    }

    (:test)
    static function peakLoadKeepsAtLeastTwoKilobytesFree(logger as Test.Logger) as Boolean {
        warmMemoryPaths();

        var peakResult = measurePeakLoad();
        Test.assertMessage(peakResult["surfaceReady"] as Boolean, "Peak load test needs a render surface.");
        if (!(peakResult["surfaceReady"] as Boolean)) {
            return false;
        }

        var peakUsed = peakResult["peakUsed"] as Number;
        var totalMemory = peakResult["totalMemory"] as Number;
        var freeBuffer = totalMemory - peakUsed;

        System.println(
            "peak_buffer peakUsed=" + peakUsed.format("%d") +
            " totalMemory=" + totalMemory.format("%d") +
            " freeBuffer=" + freeBuffer.format("%d")
        );

        Test.assertMessage((peakResult["triggerCount"] as Number) >= 1, "Peak load test must enter the active reminder path.");
        Test.assertMessage(freeBuffer >= 2048, "Peak load must keep at least 2048 bytes of free memory.");
        return true;
    }

    (:test)
    static function renderFramesReleaseTemporaryMemory(logger as Test.Logger) as Boolean {
        warmMemoryPaths();

        var renderResult = measureRenderCleanup();
        Test.assertMessage(renderResult["surfaceReady"] as Boolean, "Render cleanup test needs a render surface.");
        if (!(renderResult["surfaceReady"] as Boolean)) {
            return false;
        }

        var baselineUsed = renderResult["baselineUsed"] as Number;
        var afterUsed = renderResult["afterUsed"] as Number;
        var delta = absNumber(afterUsed - baselineUsed);

        System.println(
            "render_summary baselineUsed=" + baselineUsed.format("%d") +
            " afterUsed=" + afterUsed.format("%d") +
            " delta=" + delta.format("%d") +
            " tolerance=" + MEMORY_CACHE_TOLERANCE_BYTES.format("%d") +
            " peakUsed=" + (renderResult["peakUsed"] as Number).format("%d")
        );

        Test.assertMessage(delta <= MEMORY_CACHE_TOLERANCE_BYTES, "Rendered frame temporaries must settle within the observed simulator cache floor of 512 bytes.");
        return true;
    }
}
