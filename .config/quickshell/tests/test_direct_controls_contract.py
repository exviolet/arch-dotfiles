from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
RAIL = (ROOT / "Rail.qml").read_text()
SHELL = (ROOT / "shell.qml").read_text()
BRIGHTNESS_PATH = ROOT / "BrightnessService.qml"
BRIGHTNESS = BRIGHTNESS_PATH.read_text() if BRIGHTNESS_PATH.exists() else ""


class DirectControlContractTests(unittest.TestCase):
    def test_audio_entry_supports_wheel_and_middle_click(self):
        self.assertIn('function adjustAudioVolume(delta: real, screen: string): string', SHELL)
        self.assertIn('function toggleAudioMuteWithFeedback(screen: string): string', SHELL)
        self.assertIn('onWheel: wheel =>', RAIL)
        self.assertIn('mouse.button === Qt.MiddleButton', RAIL)

    def test_brightness_is_laptop_backlight_only(self):
        self.assertTrue(BRIGHTNESS_PATH.exists())
        self.assertIn('"--class=backlight"', BRIGHTNESS)
        self.assertIn('intel_backlight', BRIGHTNESS)
        self.assertNotIn('ddcutil', BRIGHTNESS.lower())

    def test_brightness_control_has_feedback_and_compact_state(self):
        self.assertIn('id: brightnessBlock', RAIL)
        self.assertIn('brightnessState.adjust(', RAIL)
        self.assertIn('function onFeedbackRequested(value: real, screen: string): void', SHELL)
        self.assertIn('brightnessState: brightnessService', SHELL)


if __name__ == "__main__":
    unittest.main()
