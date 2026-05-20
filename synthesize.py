import argparse
import json
import os
import sys


def synthesize(mission_dir: str, milestone: str) -> None:
    flows_dir = os.path.join(mission_dir, "validation", milestone, "user-testing", "flows")
    state_file = os.path.join(mission_dir, "validation-state.json")
    synthesis_file = os.path.join(mission_dir, "validation", milestone, "user-testing", "synthesis.json")

    with open(state_file, "r") as f:
        state = json.load(f)

    synthesis = {
        "milestone": milestone,
        "round": 1,
        "status": "fail",
        "assertionsSummary": {"total": 0, "passed": 0, "failed": 0, "blocked": 0},
        "passedAssertions": [],
        "failedAssertions": [],
        "blockedAssertions": [],
        "appliedUpdates": [],
        "previousRound": None,
    }

    for filename in os.listdir(flows_dir):
        if not filename.endswith(".json"):
            continue
        with open(os.path.join(flows_dir, filename), "r") as f:
            flow_report = json.load(f)

        for assertion_id, result in flow_report.get("results", {}).items():
            synthesis["assertionsSummary"]["total"] += 1
            status = result.get("status")
            reason = result.get("reason", "")

            if status == "pass":
                synthesis["assertionsSummary"]["passed"] += 1
                synthesis["passedAssertions"].append(assertion_id)
                state["assertions"][assertion_id] = {
                    "status": "passed",
                    "validatedAtMilestone": milestone,
                }
            elif status == "fail":
                synthesis["assertionsSummary"]["failed"] += 1
                synthesis["failedAssertions"].append({"id": assertion_id, "reason": reason})
                state["assertions"][assertion_id] = {"status": "failed", "reason": reason}
            elif status == "blocked":
                synthesis["assertionsSummary"]["blocked"] += 1
                synthesis["blockedAssertions"].append({"id": assertion_id, "blockedBy": reason})
                state["assertions"][assertion_id] = {
                    "status": "failed",
                    "reason": f"Blocked: {reason}",
                }

    with open(synthesis_file, "w") as f:
        json.dump(synthesis, f, indent=2)

    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)

    print("Synthesis complete.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Synthesize mission validation flow reports.")
    parser.add_argument(
        "--mission-dir",
        default=os.environ.get("MISSION_DIR"),
        help="Path to the mission directory (or set MISSION_DIR env var).",
    )
    parser.add_argument(
        "--milestone",
        default=os.environ.get("MISSION_MILESTONE", "misc-manual-followup"),
        help="Milestone identifier (or set MISSION_MILESTONE env var).",
    )
    args = parser.parse_args()

    if not args.mission_dir:
        parser.error("--mission-dir is required (or set MISSION_DIR).")

    synthesize(args.mission_dir, args.milestone)
    return 0


if __name__ == "__main__":
    sys.exit(main())
