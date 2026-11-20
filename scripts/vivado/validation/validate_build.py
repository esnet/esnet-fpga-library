"""Validate a routed Vivado design; emit reports, JSON, and JUnit XML."""
import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import math
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
import zlib

CATEGORIES = ("integrity", "timing", "routing", "constraints", "critical_warnings", "cdc", "drc", "methodology")
REPORTS = ("check_timing", "timing", "bus_skew", "routing", "cdc", "cdc_waived", "drc", "methodology", "waivers")
MESSAGE = re.compile(r"^(CRITICAL WARNING|ERROR):\s*(?:\[([^\]]+)\]\s*)?(.*)$")


def finding(category, ident, detail, count=1, source=""):
    return dict(category=category, id=ident, detail=detail, count=count, source=source)


def timing_findings(text):
    match = re.search(r"^\s*WNS\(ns\).*?WPWS\(ns\).*\n[^\n]*\n([^\n]+)", text, re.M)
    if not match:
        raise ValueError("Missing design timing summary")
    values = match[1].split()
    if len(values) != 12:
        raise ValueError("Unrecognized design timing summary")
    numbers = [float(value) for value in values]
    if any(not math.isfinite(value) for value in numbers):
        raise ValueError("Non-finite timing results")
    results = []
    for offset, name in [(0, "setup"), (4, "hold"), (8, "pulse_width")]:
        slack, total, failed, endpoints = numbers[offset:offset + 4]
        if endpoints <= 0:
            raise ValueError(f"No {name} endpoints analyzed")
        if slack < 0 or total < 0 or failed != 0:
            results.append(finding("timing", name, f"Worst slack {slack} ns, total slack {total} ns, failing endpoints {failed:g}"))
    return results


def bus_skew_findings(text):
    if "Bus Skew Report Summary" not in text and not re.search(r"no bus.skew|no.*bus skew", text, re.I):
        raise ValueError("Unrecognized bus skew report")
    violations = re.findall(r"Slack\s*\(VIOLATED\)\s*:\s*(-?[\d.]+)ns", text)
    return [finding("timing", "bus_skew", f"Violated bus skew paths; worst slack {min(map(float, violations))} ns", len(violations))] if violations else []


def routing_findings(text):
    metrics = {}
    for key in ["routable nets", "fully routed nets", "nets with routing errors"]:
        match = re.search(r"# of " + key + r"\.+\s*:\s*(\d+)", text)
        if not match:
            raise ValueError(f"Missing route status: {key}")
        metrics[key] = int(match[1])
    if metrics["routable nets"] != metrics["fully routed nets"] or metrics["nets with routing errors"]:
        return [finding("routing", "route_status", json.dumps(metrics, sort_keys=True))]
    return []


def coverage_findings(text):
    sections = list(re.finditer(r"^\d+\. checking (\w+) \((\d+)\)\s*\n-+\n", text, re.M))
    if not sections:
        raise ValueError("Missing check_timing sections")
    results = []
    for i, section in enumerate(sections):
        name, count = section[1], int(section[2])
        if count:
            detail = text[section.end():sections[i + 1].start() if i + 1 < len(sections) else len(text)].strip()
            if name in ("no_input_delay", "no_output_delay"):
                # Vivado's heading also counts ports with explicit false paths
                # or output clocks. Only the first group lacks timing coverage.
                direction = "input" if name == "no_input_delay" else "output"
                port = r"input ports?" if direction == "input" else r"ports?"
                missing = re.search(r"There (?:is|are) (\d+) " + port +
                                    " with no " + direction + r" delay specified\.", detail)
                classified = re.findall(r"There (?:is|are) (\d+) " + port + " with no " + direction +
                                        r" delay(?: specified\.| but user has a false path constraint|"
                                        r" but with a timing clock defined on it or propagating through it)", detail)
                if not missing or sum(map(int, classified)) != count:
                    raise ValueError(f"Unrecognized {name} coverage breakdown")
                count = int(missing[1])
                detail = re.split(r"\n\s*There (?:is|are) \d+", detail, maxsplit=1)[0].strip()
            if count:
                results.append(finding("constraints", name, detail, count))
    return results


def rule_findings(text, category):
    if category == "cdc":
        if "CDC Report" not in text:
            raise ValueError("Unrecognized CDC report")
        rows = re.findall(r"^(CDC-\d+)\s+(Critical|Warning|Info)\s+(\d+)\s+([^\n]+)", text, re.M)
        empty_table = re.search(r"^ID\s+Severity\s+Count\s+Description\s*\n[- ]+\n\s*\Z", text, re.M)
        if not rows and not empty_table and not re.search(r"no.*CDC|no.*crossing", text, re.I):
            raise ValueError("Missing CDC summary")
        return [finding(category, rule, f"{severity}: {detail}", int(count))
                for rule, severity, count, detail in rows if severity != "Info" and int(count)]
    if re.search(r"no (?:DRC|methodology) violations found", text, re.I):
        return []
    if "REPORT SUMMARY" not in text:
        raise ValueError(f"Unrecognized {category} report")
    rows = re.findall(r"^\|\s*(\S+)\s*\|\s*(Critical Warning|Error|Warning|Info|Advisory)\s*\|\s*(.*?)\s*\|\s*(\d+)\s*\|", text, re.M)
    if not rows and not re.search(r"Checks found:\s*0|no.*violations|no.*checks", text, re.I):
        raise ValueError(f"Missing {category} summary")
    return [finding(category, rule, f"{severity}: {detail}", int(count))
            for rule, severity, detail, count in rows if severity in ("Critical Warning", "Error") and int(count)]


def load_waivers(paths):
    waivers = []
    for path in paths:
        data = json.loads(path.read_text())
        if not isinstance(data, dict) or set(data) != {"waivers"} or not isinstance(data["waivers"], list):
            raise ValueError(f"Invalid waiver file {path}")
        for waiver in data["waivers"]:
            required = {"name", "category", "id", "detail", "source", "max_count", "reason"}
            if not isinstance(waiver, dict) or set(waiver) - (required | {"builds", "evidence"}) or not required <= set(waiver):
                raise ValueError(f"Invalid waiver fields in {path}")
            if any(not isinstance(waiver[key], str) for key in required - {"max_count"}):
                raise ValueError("Waiver identifiers, patterns, and rationale must be strings")
            if "builds" in waiver and (not isinstance(waiver["builds"], list) or not waiver["builds"]
                    or any(not isinstance(build, str) for build in waiver["builds"])):
                raise ValueError("Waiver builds must be a nonempty list of build names")
            if "evidence" in waiver:
                if not isinstance(waiver["evidence"], list) or not waiver["evidence"]:
                    raise ValueError("Waiver evidence must be a nonempty list")
                for check in waiver["evidence"]:
                    if (not isinstance(check, dict) or not {"input", "pattern"} <= set(check)
                            or set(check) - {"input", "pattern", "member"}
                            or any(not isinstance(value, str) or not value.strip() for value in check.values())):
                        raise ValueError("Evidence requires an input name, pattern, and optional ZIP member")
                    try:
                        re.compile(check["pattern"])
                    except re.error as error:
                        raise ValueError(f"Invalid evidence pattern: {error}") from error
            if waiver["category"] not in ("constraints", "critical_warnings"):
                raise ValueError("Use native Vivado waivers for CDC/DRC/methodology; timing cannot be waived")
            if not waiver["reason"].strip() or not waiver["name"].strip():
                raise ValueError("Waivers require a name and rationale")
            if type(waiver["max_count"]) is not int or waiver["max_count"] < 1:
                raise ValueError("Waiver max_count must be positive")
            try:
                for key in ("detail", "source"):
                    re.compile(waiver[key])
            except re.error as error:
                raise ValueError(f"Invalid waiver pattern: {error}") from error
            if any(w["name"] == waiver["name"] for w in waivers):
                raise ValueError(f"Duplicate waiver {waiver['name']}")
            waivers.append(waiver)
    return waivers


def check_waiver_evidence(waivers, inputs, checkpoint, name):
    """Check declared build artifacts; missing, newer, or ambiguous evidence fails closed."""
    paths = {}
    for label, path in inputs:
        if label in paths:
            raise ValueError(f"Duplicate waiver input {label}")
        paths[label] = path
    records, errors, eligible = [], [], []
    for waiver in waivers:
        if name not in waiver.get("builds", [name]):
            eligible.append(waiver)
            continue
        valid = True
        for check in waiver.get("evidence", []):
            record = dict(waiver=waiver["name"], **check, passed=False)
            try:
                path = paths.get(check["input"])
                if path is None:
                    raise ValueError(f"No path supplied for waiver input {check['input']}")
                record["path"] = str(path.resolve())
                if path.stat().st_mtime_ns > checkpoint.stat().st_mtime_ns:
                    raise ValueError(f"Waiver input {path} is newer than the routed checkpoint")
                data = path.read_bytes()
                record["sha256"] = hashlib.sha256(data).hexdigest()
                if "member" in check:
                    with zipfile.ZipFile(io.BytesIO(data)) as archive:
                        if archive.namelist().count(check["member"]) != 1:
                            raise ValueError(f"Expected exactly one ZIP member {check['member']}")
                        data = archive.read(check["member"])
                text = data.decode("utf-8")
                count = sum(1 for _ in re.finditer(check["pattern"], text))
                if count != 1:
                    raise ValueError(f"Evidence pattern matched {count} times; expected exactly once")
                record["passed"] = True
            except (OSError, ValueError, KeyError, zipfile.BadZipFile, RuntimeError, EOFError, zlib.error) as error:
                valid = False
                record["error"] = str(error)
                errors.append(finding("integrity", "waiver_evidence", f"{waiver['name']} ({check['input']}): {error}", source=check["input"]))
            records.append(record)
        if valid:
            eligible.append(waiver)
    return eligible, records, errors


def apply_waivers(findings, waivers, name):
    used, waived = {}, []
    active = []
    for item in findings:
        match = None
        for waiver in waivers:
            if name not in waiver.get("builds", [name]):
                continue
            if (item["category"] == waiver["category"] and item["id"] == waiver["id"]
                    and re.fullmatch(waiver["detail"], item["detail"], re.S)
                    and re.fullmatch(waiver["source"], item["source"])):
                total = used.get(waiver["name"], 0) + item["count"]
                if total <= waiver["max_count"]:
                    match = waiver
                    used[waiver["name"]] = total
                    break
        if match:
            waived.append(dict(item, waiver=match["name"], reason=match["reason"]))
        else:
            active.append(item)
    unused = [w["name"] for w in waivers if w["name"] not in used and name in w.get("builds", [name])]
    return active, waived, unused


def log_findings(paths):
    results = []
    for path, label in paths:
        try:
            lines = path.read_text(errors="replace").splitlines()
        except OSError as error:
            results.append(finding("integrity", "unreadable_log", str(error), source=label))
            continue
        severities = {}
        for line in lines:
            record = re.match(r"^(INFO|WARNING|CRITICAL WARNING|ERROR): \[([^\]]+)\]", line)
            if record:
                severities[record[2]] = record[1]
        for index, line in enumerate(lines):
            match = MESSAGE.match(line)
            if match:
                detail = [match[3]]
                following = index + 1
                if match[2] == "Vivado 12-1790":
                    while following < len(lines) and not lines[following].strip():
                        following += 1
                    if following < len(lines) and lines[following] == "Evaluation cores found in this design:":
                        detail.append(lines[following])
                        following += 1
                        while following < len(lines):
                            continuation = lines[following]
                            if continuation.strip() and not continuation[:1].isspace():
                                break
                            if continuation.strip():
                                detail.append(continuation.strip())
                            following += 1
                        # A truncated feature list must never match a complete-list waiver.
                        if following == len(lines) or not lines[following].startswith("Resolution:"):
                            detail.append("[Incomplete evaluation license details]")
                else:
                    for continuation in lines[following:]:
                        if not continuation.strip() or not continuation[:1].isspace():
                            break
                        detail.append(continuation.strip())
                results.append(finding("critical_warnings", match[2] or match[1], "\n".join(detail), source=label))
            suppression = re.search(r"suppress|limit.*reached", line, re.I)
            if suppression and ("CRITICAL WARNING" in line or "[Common 17-14]" in line):
                ident = re.search(r"Message ['\"]([^'\"]+)", line)
                severity = severities.get(ident[1]) if ident else None
                if severity not in ("INFO", "WARNING"):
                    results.append(finding("integrity", "suppressed_messages", line, source=label))
    return list({(f["category"], f["id"], f["detail"], f["source"]): f for f in results}.values())


def write_results(output, summary):
    output.mkdir(parents=True, exist_ok=True)
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    suite = ET.Element("testsuite", name="vivado_build_validation", tests=str(len(CATEGORIES)),
                       failures=str(sum(any(f["category"] == c for f in summary["findings"]) for c in CATEGORIES)))
    for category in CATEGORIES:
        case = ET.SubElement(suite, "testcase", classname=summary["name"], name=category)
        failures = [f for f in summary["findings"] if f["category"] == category]
        if failures:
            ET.SubElement(case, "failure", message=f"{sum(f['count'] for f in failures)} unwaived findings").text = json.dumps(failures, indent=2)
        elif not summary["checked"].get(category, False):
            ET.SubElement(case, "skipped", message="Required inputs or reports unavailable; see integrity failures")
    ET.ElementTree(suite).write(output / "junit.xml", encoding="utf-8", xml_declaration=True)


def named_path(value):
    name, separator, path = value.partition("=")
    if not separator or not name or not path:
        raise argparse.ArgumentTypeError("Expected NAME=PATH")
    return name, Path(path)


def print_summary(output, summary, collection_error=None):
    print(f"\nValidation summary ({summary['name']})")
    passed = summary["passed"] and collection_error is None
    print("Validation: " + ("PASS" if passed else "FAIL"))
    if collection_error:
        print(collection_error)
    for category in CATEGORIES:
        count = sum(f["count"] for f in summary["findings"] if f["category"] == category)
        state = "FAIL" if count else "PASS" if summary["checked"].get(category) else "INCOMPLETE"
        print(f"{category}: {state} ({count} unwaived findings)")
    if summary["unused_waivers"]:
        print("Unused waivers: " + ", ".join(summary["unused_waivers"]))
    print(f"Results: {output / 'summary.json'}")
    return 0 if passed else 1


def saved_summary(output, status_file=None):
    try:
        collection_error = None
        if status_file is not None:
            status = status_file.read_text().strip()
            if status != "0":
                collection_error = f"Validation collection exit status: {status!r}; see build log"
        if not (output / "junit.xml").is_file() or not (output / "junit.xml").stat().st_size:
            raise ValueError("Missing or empty JUnit results")
        summary = json.loads((output / "summary.json").read_text())
        if (not isinstance(summary["name"], str) or type(summary["passed"]) is not bool
                or not isinstance(summary["findings"], list)
                or not isinstance(summary["unused_waivers"], list)
                or any(type(summary["checked"][category]) is not bool for category in CATEGORIES)
                or summary["passed"] != (not summary["findings"])):
            raise ValueError("Invalid validation summary")
        for item in summary["findings"]:
            if item["category"] not in CATEGORIES or type(item["count"]) is not int or item["count"] < 1:
                raise ValueError("Invalid validation finding")
        if summary["passed"] and not all(summary["checked"].values()):
            raise ValueError("Passing summary contains incomplete checks")
        return print_summary(output, summary, collection_error)
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Validation: FAIL (saved summary unavailable or invalid: {error})")
        return 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--summary-only", action="store_true", help="Print saved results and return their status without invoking Vivado")
    parser.add_argument("--status-file", type=Path, help="Require a successful collection status file when replaying a saved summary")
    parser.add_argument("--input", type=Path, action="append", default=[], help="Required input that must not be newer than the checkpoint")
    parser.add_argument("--log", type=named_path, action="append", default=[], metavar="NAME=PATH", help="Required build log")
    parser.add_argument("--transcript", type=named_path, action="append", default=[], metavar="NAME=PATH", help="Required run_logged.py transcript with a successful exit marker")
    parser.add_argument("--log-root", type=named_path, action="append", default=[], metavar="NAME=PATH", help="Directory of active Vivado operation/run logs to inspect recursively")
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--name", default=None, help="Build label for JUnit and waiver selection; defaults to the checkpoint stem")
    parser.add_argument("--waiver-input", type=named_path, action="append", default=[], metavar="NAME=PATH",
                        help="Generated artifact used by JSON waiver evidence checks; must not be newer than the checkpoint")
    parser.add_argument("--waivers", type=Path, action="append", default=[])
    parser.add_argument("--waiver-tcl", type=Path, action="append", default=[])
    parser.add_argument("--waiver-ref", type=named_path, action="append", default=[], metavar="REF=PATH",
                        help="Native waiver XDC applied to all instances of a module reference")
    parser.add_argument("--vivado", default="vivado")
    args = parser.parse_args(argv)
    output = args.output_dir.resolve()
    if args.summary_only:
        return saved_summary(output, args.status_file)
    if args.status_file is not None:
        parser.error("--status-file requires --summary-only")
    if args.checkpoint is None:
        parser.error("--checkpoint is required unless --summary-only is used")
    summary = dict(name=args.name or args.checkpoint.stem, checkpoint=str(args.checkpoint.resolve()),
                   timestamp=datetime.now(timezone.utc).isoformat(), findings=[], waived=[], unused_waivers=[])
    findings = summary["findings"]
    waivers = []
    parsed = set()
    # Remove previous validation outputs so a failed run cannot reuse stale reports.
    output.mkdir(parents=True, exist_ok=True)
    for name in [*(r + ".rpt" for r in REPORTS), "report_status.tsv", "summary.json", "junit.xml", "vivado.log", "transcript.log"]:
        (output / name).unlink(missing_ok=True)
    try:
        waivers = load_waivers(args.waivers)
        for path in args.waiver_tcl + [path for _, path in args.waiver_ref]:
            if not path.is_file():
                raise ValueError(f"Missing native waiver file {path}")
        if not args.checkpoint.is_file():
            raise ValueError(f"Missing final routed checkpoint {args.checkpoint}")
        digest = hashlib.sha256()
        with args.checkpoint.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        summary["checkpoint_sha256"] = digest.hexdigest()
        for dependency in args.input:
            if not dependency.is_file():
                findings.append(finding("integrity", "missing_input", f"Missing checkpoint input {dependency}"))
            elif dependency.stat().st_mtime_ns > args.checkpoint.stat().st_mtime_ns:
                findings.append(finding("integrity", "stale_checkpoint", f"{dependency} is newer than the routed checkpoint"))
        command = [args.vivado, "-mode", "batch", "-notrace", "-nojournal", "-log", str(output / "vivado.log"),
                   "-source", str(Path(__file__).with_name("report_build.tcl")), "-tclargs",
                   str(args.checkpoint.resolve()), str(output), *(str(p.resolve()) for p in args.waiver_tcl)]
        for reference, path in args.waiver_ref:
            command += ["-waiver-ref", reference, str(path.resolve())]
        with (output / "transcript.log").open("w") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            findings.append(finding("integrity", "vivado", f"Report process exited {result.returncode}; see transcript.log"))
        status_path = output / "report_status.tsv"
        statuses = dict(line.split("\t", 1) for line in status_path.read_text().splitlines()) if status_path.exists() else {}
        for report in ("checkpoint", *REPORTS):
            if statuses.get(report) != "OK":
                findings.append(finding("integrity", report, statuses.get(report, "Report was not generated")))
            elif report != "checkpoint" and not (output / (report + ".rpt")).is_file():
                findings.append(finding("integrity", report, "Report file is missing"))
        checks = {"timing": timing_findings, "bus_skew": bus_skew_findings, "routing": routing_findings,
                  "check_timing": coverage_findings, "cdc": lambda s: rule_findings(s, "cdc"),
                  "drc": lambda s: rule_findings(s, "drc"), "methodology": lambda s: rule_findings(s, "methodology")}
        if statuses.get("cdc_waived") == "OK":
            try:
                summary["native_waived_cdc"] = rule_findings((output / "cdc_waived.rpt").read_text(), "cdc")
            except (OSError, ValueError) as error:
                findings.append(finding("integrity", "cdc_waived", str(error)))
        for report, check in checks.items():
            if statuses.get(report) == "OK":
                try:
                    findings.extend(check((output / (report + ".rpt")).read_text()))
                    parsed.add(report)
                except (OSError, ValueError) as error:
                    findings.append(finding("integrity", report, str(error)))
    except (OSError, ValueError) as error:
        findings.append(finding("integrity", "inputs", str(error)))
    logs = []
    for label, path in args.log + args.transcript:
        if not path.is_file():
            findings.append(finding("integrity", "build_log", f"Missing {label} log {path}"))
            continue
        logs.append((path, label))
        if (label, path) in args.transcript:
            try:
                if not path.read_text(errors="replace").rstrip().endswith("BUILD_EXIT_CODE=0"):
                    findings.append(finding("integrity", "build_log", f"Incomplete or failed {label} transcript"))
            except OSError as error:
                findings.append(finding("integrity", "unreadable_log", str(error), source=label))
    seen_roots = set()
    for label, root in args.log_root:
        if root.resolve() in seen_roots:
            continue
        seen_roots.add(root.resolve())
        if not root.is_dir():
            findings.append(finding("integrity", "build_log", f"Missing {label} log directory {root}"))
            continue
        for path in root.rglob("*.log"):
            if output == path.parent.resolve() or output in path.resolve().parents:
                continue
            if ".backup." not in path.name and (path.name in ("runme.log", "vivado.log") or
                    re.search(r"\.(synth|link|opt|place|place_opt|route|route_opt|bitstream|device_image|xsa|create_proj|create_ip|create_bd|remove_ip|remove_bd|reset|status|upgrade|exdes|gui)\.log$", path.name)):
                logs.append((path, label + "/" + path.relative_to(root).as_posix()))
    if not logs:
        findings.append(finding("integrity", "build_log", "No inspectable build logs supplied"))
    if (output / "transcript.log").exists():
        logs.append((output / "transcript.log", "validation"))
    findings.extend(log_findings(logs))
    requirements = {"timing": {"timing", "bus_skew"}, "routing": {"routing"}, "constraints": {"check_timing"},
                    "cdc": {"cdc"}, "drc": {"drc"}, "methodology": {"methodology"}}
    summary["checked"] = {category: reports <= parsed for category, reports in requirements.items()}
    summary["checked"]["integrity"] = True
    summary["checked"]["critical_warnings"] = not any(f["category"] == "integrity" and f["id"] in
                                                        ("build_log", "unreadable_log", "suppressed_messages") for f in findings)
    eligible = []
    summary["waiver_evidence"] = []
    try:
        eligible, summary["waiver_evidence"], errors = check_waiver_evidence(
            waivers, args.waiver_input, args.checkpoint, summary["name"])
        findings.extend(errors)
    except ValueError as error:
        findings.append(finding("integrity", "waiver_evidence", str(error)))
    summary["findings"], summary["waived"], _ = apply_waivers(findings, eligible, summary["name"])
    used = {item["waiver"] for item in summary["waived"]}
    summary["unused_waivers"] = [w["name"] for w in waivers
                                   if w["name"] not in used and summary["name"] in w.get("builds", [summary["name"]])]
    summary["logs"] = [str(p) for p, _ in logs]
    summary["passed"] = not summary["findings"]
    write_results(output, summary)
    return print_summary(output, summary)


if __name__ == "__main__":
    sys.exit(main())
