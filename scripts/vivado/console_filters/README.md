# Console filter profiles

The [logged command runner](../../run_logged.md), invoked with
`--console-filter <file.json>`, applies these rules only to
console output. The complete merged command output still goes to the
transcript. Rules use Python regular expressions and are tested with
`search()` against each line, excluding the line terminator. ANSI CSI
sequences, including colors, are removed for matching only; original text
is retained in both outputs.

The runner has no built-in tool-specific patterns. `vivado-progress.json`
is a supplied profile for native Vivado and OpenNIC builds. Other tools can
supply their own rules:

```json
{
  "progress": ["^STEP "],
  "diagnostics": ["^ALERT "],
  "warning": {
    "pattern": "^NOTICE (?P<id>[A-Z0-9-]+):",
    "limit": 3
  },
  "continuation": "^(?:[ \\t]+\\S|[ \\t]*$)"
}
```

`progress` and `diagnostics` are required lists. `warning` and
`continuation` are optional. Invalid fields, types, or patterns are rejected
before opening the log or launching the command.

Rules are evaluated in this order:

1. `diagnostics`: always display the line and any matching continuations.
2. `warning`: count the message by its named `id` capture and display the
   first `limit` occurrences. Its continuation lines follow the same
   visibility decision. `limit` must be a positive integer.
3. `progress`: display the line and remember it as the latest milestone.
4. `continuation`: after a diagnostic or warning, display or omit matching
   continuation lines with that message. Another recognized message starts
   a new context; an unrelated non-continuation line ends the old context.
5. Everything else: omit from the console, retaining it in the transcript.

The first omitted warning occurrence produces a notice. At completion,
each warning ID that exceeded its limit gets total and omitted counts.
Limits apply across the entire command, including recursive child builds.

The supplied Vivado profile never rate-limits critical warnings, errors,
or warnings without a message ID. Custom profiles own their own diagnostic
policy. A failing command also gets an unfiltered, bounded tail replay so
unexpected failure output remains available in the console.

Filtering does not decide command success or waive validation findings.
Enablement in CI and transcript artifact publication belong to the calling
repository, not to this library.
