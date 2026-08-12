from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
RAIL = (ROOT / "Rail.qml").read_text()
SHELL = (ROOT / "shell.qml").read_text()


class OrientationContractTests(unittest.TestCase):
    def test_rail_distinguishes_output_identity_and_focus(self):
        self.assertIn('readonly property bool outputFocused:', RAIL)
        self.assertIn('function outputIdentity(): string', RAIL)
        self.assertIn('id: outputIdentityLabel', RAIL)
        self.assertIn('id: outputFocusSpine', RAIL)

    def test_focus_handoff_is_a_bounded_one_shot(self):
        self.assertIn('id: outputFocusPulseAnimation', RAIL)
        self.assertIn('onOutputFocusedChanged:', RAIL)
        self.assertIn('PauseAnimation', RAIL)
        self.assertNotIn('loops: Animation.Infinite', RAIL)

    def test_keyboard_feedback_is_event_driven_and_testable(self):
        self.assertIn('function onKeyboardLayoutChanged(): void', SHELL)
        self.assertIn('function showKeyboardLayout(screen: string): string', SHELL)
        self.assertIn('root.kind = "keyboard"', SHELL)
        self.assertIn('id: layoutOptions', SHELL)

    def test_keyboard_feedback_uses_focused_output_by_default(self):
        self.assertIn('screen === "" ? niriService.focusedOutput : screen', SHELL)
        self.assertIn('keyboardFeedbackReady', SHELL)

    def test_keyboard_feedback_uses_matching_active_tile_colors(self):
        self.assertIn('readonly property color layoutUs:', SHELL)
        self.assertIn('readonly property color layoutRu:', SHELL)
        self.assertIn('readonly property color layoutKk:', SHELL)
        self.assertIn('function keyboardLayoutColor(name: string): color', SHELL)
        self.assertIn('color: active ? root.keyboardLayoutColor(modelData) : root.track', SHELL)
        self.assertIn('keyboardLayoutCode(name) === "KK" ? "#171817" : "#ffffff"', SHELL)


if __name__ == "__main__":
    unittest.main()
