import argparse
import json
import os
import sys


PASSED_ASSERTIONS = [
    "VAL-CROSS-002", "VAL-CROSS-004", "VAL-CROSS-014",
    "VAL-M2-CONFLICT-001", "VAL-M2-CONFLICT-002", "VAL-M2-CONFLICT-003",
    "VAL-M2-CONFLICT-004", "VAL-M2-CONFLICT-005", "VAL-M2-CONFLICT-006",
    "VAL-M2-CONFLICT-007", "VAL-M2-CONFLICT-008", "VAL-M2-CONFLICT-009",
    "VAL-M2-PROMOTE-002", "VAL-M2-PROMOTE-003", "VAL-M2-PROMOTE-004",
    "VAL-M2-PROMOTE-005", "VAL-M2-PROMOTE-006", "VAL-M2-PROMOTE-007",
    "VAL-M2-PROMOTE-008", "VAL-M2-PROMOTE-009",
]

BLOCKED_ASSERTIONS = ["VAL-M2-CONFLICT-010", "VAL-M2-PROMOTE-001"]

BLOCKED_REASON = (
    "osascript failed with error -1719 (Invalid index) and screencapture failed "
    "with 'could not create image from display', indicating a headless environment "
    "or missing accessibility/screen recording permissions."
)


def update(state_file: str, milestone: str) -> None:
    with open(state_file, "r") as f:
        data = json.load(f)

    for assertion in PASSED_ASSERTIONS:
        data["assertions"][assertion]["status"] = "passed"
        data["assertions"][assertion]["validatedAtMilestone"] = milestone

    for assertion in BLOCKED_ASSERTIONS:
        data["assertions"][assertion]["status"] = "failed"
        data["assertions"][assertion]["issues"] = BLOCKED_REASON

    with open(state_file, "w") as f:
        json.dump(data, f, indent=2)


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply validation status updates to a mission.")
    parser.add_argument(
        "--state-file",
        default=os.environ.get("VALIDATION_STATE_FILE"),
        help="Path to validation-state.json (or set VALIDATION_STATE_FILE env var).",
    )
    parser.add_argument(
        "--mission-dir",
        default=os.environ.get("MISSION_DIR"),
        help="Mission directory; resolves to <dir>/validation-state.json when --state-file is omitted.",
    )
    parser.add_argument(
        "--milestone",
        default=os.environ.get("MISSION_MILESTONE", "m2-routing-surfacing"),
        help="Milestone identifier (or set MISSION_MILESTONE env var).",
    )
    args = parser.parse_args()

    state_file = args.state_file
    if not state_file and args.mission_dir:
        state_file = os.path.join(args.mission_dir, "validation-state.json")
    if not state_file:
        parser.error("Provide --state-file or --mission-dir.")

    update(state_file, args.milestone)
    return 0


if __name__ == "__main__":
    sys.exit(main())
