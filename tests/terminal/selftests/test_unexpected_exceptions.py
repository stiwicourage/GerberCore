from __future__ import annotations

from pathlib import Path
import sys
import unittest


TERMINAL_ROOT = Path(__file__).resolve().parents[1]
if str(TERMINAL_ROOT) not in sys.path:
    sys.path.insert(0, str(TERMINAL_ROOT))

from framework.gerber_app import find_unexpected_exception


class UnexpectedExceptionDetectionTests(unittest.TestCase):
    def test_detects_visible_parameter_binding_exception(self) -> None:
        message = find_unexpected_exception(
            raw_output="",
            visible_text="Cannot bind argument to parameter 'Text' because it is an empty string.",
        )

        self.assertIsNotNone(message)
        self.assertIn("Cannot bind argument", message)

    def test_detects_powershell_stack_trace_in_raw_output(self) -> None:
        raw_output = "\n".join(
            [
                "CategoryInfo          : InvalidData: (:) [], ParameterBindingValidationException",
                "FullyQualifiedErrorId : ParameterArgumentValidationErrorEmptyStringNotAllowed,Show-GerberTextBlock",
                "at Show-GerberTextBlock, /repo/src/private/cli/Show-GerberTextBlock.ps1: line 12",
            ]
        )

        message = find_unexpected_exception(raw_output=raw_output, visible_text="")

        self.assertIsNotNone(message)
        self.assertIn("Unexpected PowerShell", message)

    def test_ignores_controlled_product_error_screen_without_exception_markers(self) -> None:
        message = find_unexpected_exception(
            raw_output="",
            visible_text="Error\nGerber could not complete that action.\nTry again in a moment.",
        )

        self.assertIsNone(message)


if __name__ == "__main__":
    unittest.main()
