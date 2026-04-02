import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:full)
class FuelPlannerReminderAlert extends WatchUi.DataFieldAlert {
    private var _titleText as String;
    private var _doseText as String;
    private var _reasonText as String;

    function initialize(titleText as String, doseText as String, reasonText as String) {
        DataFieldAlert.initialize();
        _titleText = titleText;
        _doseText = doseText;
        _reasonText = reasonText;
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var contentW = w - 24;
        if (contentW < 40) {
            contentW = 40;
        }

        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_RED);
        dc.clear();
        dc.fillRectangle(0, 0, w, h);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var titleFont = getBestFontForHeight(dc, getScaledValue(h, 0.20f, 24, 56), false);
        var doseFont = getBestFontForHeight(dc, getScaledValue(h, 0.14f, 18, 40), true);
        var reasonFont = getBestFontForHeight(dc, getScaledValue(h, 0.09f, 12, 22), false);
        var gap = getScaledValue(h, 0.025f, 6, 12);
        var titleH = dc.getTextDimensions(_titleText, titleFont)[1];
        var doseH = dc.getTextDimensions(_doseText, doseFont)[1];
        var reasonH = dc.getTextDimensions(_reasonText, reasonFont)[1];
        var totalHeight = titleH + gap + doseH + gap + reasonH;
        var y = (h - totalHeight) / 2;
        if (y < 0) {
            y = 0;
        }

        dc.drawText(w / 2, y, titleFont, _titleText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap, doseFont, _doseText, Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(w / 2, y + titleH + gap + doseH + gap, reasonFont, _reasonText, Graphics.TEXT_JUSTIFY_CENTER);

        dc.setPenWidth(4);
        dc.drawRectangle(2, 2, w - 4, h - 4);
    }

    private function getBestFontForHeight(dc as Dc, rowHeight as Number, allowNumber as Boolean) {
        var target = rowHeight;
        if (target < 1) {
            target = 1;
        }

        var hXtiny = dc.getTextDimensions("Ag", Graphics.FONT_XTINY)[1];
        var hTiny = dc.getTextDimensions("Ag", Graphics.FONT_TINY)[1];
        var hMedium = dc.getTextDimensions("Ag", Graphics.FONT_MEDIUM)[1];
        var hLarge = dc.getTextDimensions("Ag", Graphics.FONT_LARGE)[1];
        var hNumber = dc.getTextDimensions("88", Graphics.FONT_NUMBER_MILD)[1];

        var bestFont = Graphics.FONT_XTINY;
        var bestH = hXtiny;

        if (hTiny <= target && hTiny >= bestH) {
            bestFont = Graphics.FONT_TINY;
            bestH = hTiny;
        }
        if (hMedium <= target && hMedium >= bestH) {
            bestFont = Graphics.FONT_MEDIUM;
            bestH = hMedium;
        }
        if (hLarge <= target && hLarge >= bestH) {
            bestFont = Graphics.FONT_LARGE;
            bestH = hLarge;
        }
        if (allowNumber && hNumber <= target && hNumber >= bestH) {
            bestFont = Graphics.FONT_NUMBER_MILD;
        }
        return bestFont;
    }

    private function getScaledValue(size as Number, ratio as Float, minValue as Number, maxValue as Number) as Number {
        var value = (size.toFloat() * ratio).toNumber();
        if (value < minValue) {
            return minValue;
        }
        if (value > maxValue) {
            return maxValue;
        }
        return value;
    }
}
