#!/usr/bin/env python3
"""Print build status and final routed timing from an existing report."""
import argparse
from pathlib import Path
import re

from validation.validate_build import timing_findings


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--name", required=True)
    parser.add_argument("--status", required=True)
    parser.add_argument("--timing-report", type=Path)
    args = parser.parse_args(argv)
    print(f"\nBuild summary ({args.name})")
    print(f"Build: {args.status}")
    if args.status != "success":
        print("Final routed timing: unavailable (build did not succeed)")
        return 0
    try:
        if args.timing_report is None:
            raise ValueError("no timing report supplied")
        text = args.timing_report.read_text()
        failures = timing_findings(text)
        table = re.search(r"^\s*WNS\(ns\).*?WPWS\(ns\).*\n[^\n]*\n[^\n]+", text, re.M)
        print("Final routed timing: " + ("FAIL" if failures else "PASS"))
        print(table[0].strip())
    except (OSError, ValueError) as error:
        print(f"Final routed timing: unavailable ({error})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
