"""Stream a build command and retain a complete, status-marked transcript."""
import argparse
from pathlib import Path
import subprocess
import sys

STATUS = "BUILD_EXIT_CODE="


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a command is required")
    args.log.parent.mkdir(parents=True, exist_ok=True)
    with args.log.open("w") as log:
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, errors="replace")
            for line in process.stdout:
                sys.stdout.write(line)
                sys.stdout.flush()
                log.write(line)
            status = process.wait()
        except OSError as error:
            log.write(f"ERROR: {error}\n")
            print(error, file=sys.stderr)
            status = 127
        log.write(f"\n{STATUS}{status}\n")
    return status if status >= 0 else 128 - status


if __name__ == "__main__":
    sys.exit(main())
