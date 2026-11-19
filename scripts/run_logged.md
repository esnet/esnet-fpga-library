# Logged command runner

`run_logged.py` runs an arbitrary command, streams its output, and retains
a complete merged stdout/stderr transcript. It has no Vivado or validation
dependencies.

Capture commands while preserving their exit status with:

```sh
python3 "$SCRIPTS_ROOT/run_logged.py" \
  --log output/export.log -- make image
```

Console output is unfiltered by default. To select the supplied Vivado
progress profile while retaining the complete transcript:

```sh
python3 "$SCRIPTS_ROOT/run_logged.py" \
  --log output/build.log \
  --console-filter "$SCRIPTS_ROOT/vivado/console_filters/vivado-progress.json" \
  -- make build
```

For targets already using `run_logged.py`, set
`RUN_LOGGED_CONSOLE_FILTER` to that absolute profile path instead of adding
another wrapper. A command-line `--console-filter` overrides the environment.
Clear the environment variable to return existing wrappers to full output.

Filtering changes console presentation only. The merged stdout/stderr
transcript and `BUILD_EXIT_CODE` marker retain the same contents and exit
semantics. Validation always reads the full log. Synthetic console banners,
heartbeats, warning summaries, and failure-tail replays are not written into
the transcript. Each wrapper records the output received from its direct
command; avoid nesting filtered wrappers when an outer transcript must
contain the original tool output.

The Vivado profile keeps custom build banners, key tool commands, inline and
final timing summaries, license status, critical warnings, errors, and
diagnostic continuations visible. It prints the first three ordinary
warnings per message ID, announces suppression,
and summarizes total/omitted occurrences when the command finishes.
License warnings and warnings without an ID are always shown. Routine INFO
output, per-cell constraint-loading chatter, and routine constraint-application
completion messages stay in the full transcript. These routine lines are
also hidden when indented after a diagnostic; constraint warnings, errors,
and timing-violation summaries retain the policies above.

In filtered mode, `--heartbeat SECONDS` prints elapsed time and the latest
milestone after that much time without console output (default: 60;
0 disables). Heartbeats also work while hidden output is arriving or after
the child closes stdout but continues running. On failure,
`--failure-tail LINES` replays the last unfiltered transcript lines
(default: 50; 0 disables). Completion shows exit status and transcript path.
Full logs are flushed at least once per second while the wrapper is running.
Unfiltered mode adds no banners, heartbeats, summaries, or tail replay.

See [console filter rules](vivado/console_filters/README.md) to customize the
profile. Profiles are independent of the runner; the runner does not
contain Vivado message IDs or build-phase patterns.
