"""Stream a command to a complete transcript, with optional console filtering."""
import argparse
from collections import Counter, deque
import json
import math
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time

STATUS = "BUILD_EXIT_CODE="
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def interval(value):
    result = float(value)
    if not math.isfinite(result) or result < 0:
        raise argparse.ArgumentTypeError("must be a finite nonnegative number")
    return result


def line_count(value):
    result = int(value)
    if result < 0:
        raise argparse.ArgumentTypeError("must be nonnegative")
    return result


class ConsoleFilter:
    """Classify lines using caller-owned rules; never alter transcript text."""
    def __init__(self, path):
        config = json.loads(path.read_text())
        required = {"progress", "diagnostics"}
        if not isinstance(config, dict) or not required <= config.keys() or config.keys() - (required | {"warning", "continuation"}):
            raise ValueError("filter requires progress and diagnostics lists; optional fields are warning and continuation")
        for key in required:
            if not isinstance(config[key], list) or any(not isinstance(p, str) or not p for p in config[key]):
                raise ValueError(f"{key} must be a list of nonempty regular expressions")
        self.progress = [re.compile(p) for p in config["progress"]]
        self.diagnostics = [re.compile(p) for p in config["diagnostics"]]
        continuation = config.get("continuation")
        if continuation is not None and (not isinstance(continuation, str) or not continuation):
            raise ValueError("continuation must be a nonempty regular expression")
        self.continuation = re.compile(continuation) if continuation else None
        self.warning = None
        self.limit = 0
        if "warning" in config:
            warning = config["warning"]
            if not isinstance(warning, dict) or set(warning) != {"pattern", "limit"}:
                raise ValueError("warning requires pattern and limit")
            if not isinstance(warning["pattern"], str) or not warning["pattern"]:
                raise ValueError("warning pattern must be a nonempty regular expression")
            if type(warning["limit"]) is not int or warning["limit"] < 1:
                raise ValueError("warning limit must be a positive integer")
            self.warning = re.compile(warning["pattern"])
            if "id" not in self.warning.groupindex:
                raise ValueError("warning pattern requires a named 'id' group")
            self.limit = warning["limit"]
        self.counts = Counter()
        self.context = False
        self.context_visible = False
        self.hidden = 0
        self.last_progress = "none yet"

    def select(self, line):
        text = ANSI.sub("", line).rstrip("\r\n")
        notice = None
        if any(pattern.search(text) for pattern in self.diagnostics):
            self.context, self.context_visible = True, True
            visible = True
        elif self.warning and (match := self.warning.search(text)):
            key = match.group("id") or match.group(0)
            self.counts[key] += 1
            visible = self.counts[key] <= self.limit
            self.context, self.context_visible = True, visible
            if self.counts[key] == self.limit + 1:
                notice = f"Further warnings with ID {key} will be counted; see the complete transcript."
        elif any(pattern.search(text) for pattern in self.progress):
            self.last_progress = text.strip()[:240]
            self.context = False
            visible = True
        elif self.context and self.continuation and self.continuation.search(text):
            visible = self.context_visible
        else:
            self.context = False
            visible = False
        if not visible:
            self.hidden += 1
        return visible, notice


def elapsed(seconds):
    seconds = int(seconds)
    return f"{seconds // 3600:02d}:{seconds // 60 % 60:02d}:{seconds % 60:02d}"


def read_output(process, events):
    try:
        for line in process.stdout:
            events.put(("line", line))
    except (OSError, ValueError) as error:
        events.put(("error", str(error)))
        if process.poll() is None:
            process.terminate()
    finally:
        process.stdout.close()
        # Keep the consumer responsive to heartbeats if stdout closes before exit.
        events.put(("done", process.wait()))


def run(command, log, policy, heartbeat, failure_tail, log_path):
    start = time.monotonic()
    last_visible = start
    last_flush = start
    tail = deque(maxlen=failure_tail)
    line_ended = True

    def emit(text):
        nonlocal last_visible, line_ended
        sys.stdout.write(text)
        sys.stdout.flush()
        last_visible = time.monotonic()
        line_ended = text.endswith("\n")

    def note(text):
        if not line_ended:
            emit("\n")
        emit(f"[run_logged] {text}\n")

    if policy:
        note(f"Command started; complete transcript: {log_path}")
    try:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, errors="replace")
    except OSError as error:
        text = f"ERROR: {error}\n"
        log.write(text)
        print(error, file=sys.stderr)
        if policy:
            note(f"Command could not start; exit code 127; transcript: {log_path}")
        return 127
    events = queue.Queue(maxsize=256)
    reader = threading.Thread(target=read_output, args=(process, events), daemon=True)
    reader.start()
    read_failed = False
    try:
        while True:
            now = time.monotonic()
            timeout = min(1.0, max(0.001, heartbeat - (now - last_visible))) if policy and heartbeat else 1.0
            try:
                kind, value = events.get(timeout=timeout)
            except queue.Empty:
                kind, value = None, None
            if kind == "done":
                status = 125 if read_failed else value
                break
            if kind == "line":
                log.write(value)
                tail.append(value)
                visible, notice = policy.select(value) if policy else (True, None)
                if visible:
                    emit(value)
                if notice:
                    note(notice)
            elif kind == "error":
                read_failed = True
                log.write(f"ERROR: Could not read command output: {value}\n")
                emit(f"ERROR: Could not read command output: {value}\n")
            now = time.monotonic()
            if now - last_flush >= 1.0:
                log.flush()
                last_flush = now
            if policy and heartbeat and now - last_visible >= heartbeat:
                note(f"Still running; elapsed {elapsed(now - start)}; last progress: {policy.last_progress}; {policy.hidden} lines filtered during streaming.")
        reader.join()
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    if policy:
        if status != 0 and tail:
            note(f"Command failed; last {len(tail)} transcript lines (unfiltered):")
            for line in tail:
                emit(line)
            if not tail[-1].endswith("\n"):
                emit("\n")
        for key, count in sorted(policy.counts.items()):
            if count > policy.limit:
                note(f"Warning {key}: {count} occurrences; {count - policy.limit} omitted from console.")
        code = status if status >= 0 else 128 - status
        note(f"Command finished; exit code {code}; elapsed {elapsed(time.monotonic() - start)}; {policy.hidden} lines filtered during streaming; complete transcript: {log_path}")
    return status


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--console-filter", type=Path,
                        default=os.environ.get("RUN_LOGGED_CONSOLE_FILTER") or None,
                        help="Console rule file; defaults to RUN_LOGGED_CONSOLE_FILTER, or unfiltered output")
    parser.add_argument("--heartbeat", type=interval, default=60,
                        help="Filtered-console heartbeat interval in seconds (default: 60; 0 disables)")
    parser.add_argument("--failure-tail", type=line_count, default=50,
                        help="Unfiltered transcript lines to replay on failure in filtered mode (default: 50)")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a command is required")
    try:
        policy = ConsoleFilter(args.console_filter) if args.console_filter else None
    except (OSError, ValueError, re.error) as error:
        parser.error(f"Invalid console filter: {error}")
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with args.log.open("w") as log:
        status = run(command, log, policy, args.heartbeat, args.failure_tail, args.log)
        log.write(f"\n{STATUS}{status}\n")
    return status if status >= 0 else 128 - status


if __name__ == "__main__":
    sys.exit(main())
