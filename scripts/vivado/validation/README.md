# Vivado build validation

This framework validates an existing routed Vivado checkpoint without
running synthesis, implementation, or programming-image generation. It has
no board, application, repository-layout, or CI dependencies. The caller
supplies a checkpoint, a build label, log inputs, and waiver files.

## Make integration

`vivado_build_non_proj.mk` includes `vivado_validate.mk`, providing the
separate `validate` target. Other flows can include it directly:

```make
VALIDATION_NAME := accelerator-a
VALIDATION_CHECKPOINT := $(OUTPUT_DIR)/final_design.dcp
VALIDATION_DIR := $(OUTPUT_DIR)/validation
VALIDATION_LOGS := synthesis=$(OUTPUT_DIR)/synthesis.log implementation=$(OUTPUT_DIR)/implementation.log
VALIDATION_TRANSCRIPTS := export=$(OUTPUT_DIR)/export.log
VALIDATION_LOG_ROOTS := generated=$(OUTPUT_DIR)/generated
VALIDATION_INPUTS := $(OUTPUT_DIR)/synthesis.dcp
include $(SCRIPTS_ROOT)/Makefiles/vivado_validate.mk
```

`VALIDATION_INPUTS` lists required files that must not be newer than the
checkpoint. Nothing is inferred from the checkpoint filename. For library
non-project components, the default checkpoint is
`$(COMPONENT_OUT_PATH)/$(TOP).route_opt.dcp`, the default output directory is
`$(COMPONENT_OUT_PATH)/validation`, and `VALIDATION_LOGS` defaults to the
component's phase logs from `BUILD_STAGES`. Set explicit inputs to include
warnings from dependencies or cached output products.

Log inputs use `NAME=PATH` syntax. The name appears in findings and can
scope waivers. `VALIDATION_LOGS` lists required text logs.
`VALIDATION_TRANSCRIPTS` lists required command transcripts produced by
`run_logged.py`; each must end in `BUILD_EXIT_CODE=0`.
`VALIDATION_LOG_ROOTS` lists directories to search recursively for current
Vivado phase/operation logs and synthesis `runme.log` files. Rotated
`*.backup.log` files are excluded. Missing inputs, unreadable logs,
incomplete transcripts, critical-warning message suppression, and having
no inspectable build logs fail the integrity check.

Capture command transcripts with the generic [logged command runner](../../run_logged.md).
Its optional console filtering leaves the full transcript unchanged.

The caller decides which stages and dependency logs establish complete
coverage of its build. The framework cannot detect an omitted dependency
that was never declared as an input.

The checker can also be invoked directly:

```sh
python3 "$SCRIPTS_ROOT/vivado/validation/validate_build.py" \
  --checkpoint output/final_design.dcp --name accelerator-a \
  --output-dir output/validation \
  --input output/synthesis.dcp \
  --log synthesis=output/synthesis.log \
  --transcript export=output/export.log \
  --log-root generated=output/generated
```

Use `VALIDATION_PYTHON` / `VALIDATION_VIVADO` to select executables in Make,
or `--vivado` on the CLI. Use the Vivado version that produced the checkpoint.

## Checks and output

Validation requires nonnegative setup, hold, and pulse-width slack, zero
failing timing endpoints, no violated bus-skew constraints, and complete
routing without routing errors. Bus-skew constraints with no applicable
paths, such as tied-off signals, may report `NA`.

Constraint-coverage findings and CDC Warning/Critical findings fail unless
waived. DRC and methodology Error/Critical Warning findings also fail.
Informational CDC findings and ordinary DRC/methodology warnings remain
visible in the full reports without failing validation. Missing or
unrecognized reports fail the integrity check. Unavailable checks appear
as incomplete/skipped, never as passing.

The output directory contains full timing, bus-skew, routing, constraint,
CDC, DRC, methodology, and waiver reports; a validation transcript;
`summary.json`; and `junit.xml`. JSON records the build name, checkpoint
hash, inspected logs, findings, JSON waiver accounting, and native waived
CDC counts. JUnit has a separate test case for each check category.
Exit status is nonzero if any unwaived finding remains.

## Console summaries and saved results

Validation always prints an overall PASS/FAIL and the per-category results
when it completes. Replay the same summary without Vivado or a checkpoint:

```sh
python3 scripts/vivado/validation/validate_build.py \
  --summary-only --output-dir output/validation
```

Replay returns the saved validation status and leaves artifacts unchanged.
Missing, malformed, inconsistent, or incomplete passing summaries fail.
JUnit results must also be present. Optionally supply `--status-file PATH`
to require a collection completion file whose content is `0`. The caller
owns writing this file after collection and choosing a path that identifies
the expected producer, so stale results cannot satisfy a new collection.

For a build-job summary, use the separate reporting script:

```sh
python3 scripts/vivado/build_summary.py --name accelerator-a --status success \
  --timing-report output/validation/timing.rpt
```

It prints the build status and final routed setup, hold, and pulse-width
timing table. Failed builds and missing or invalid reports show timing as
unavailable. This reporting command does not change the build's exit status;
validation owns the policy for accepting timing and other findings.

## Waiver selection

Waivers are owned by the design using the library. None ship enabled.

`VALIDATION_WAIVER_DIRS` defaults to `$(CURDIR)/validation`, and
`VALIDATION_WAIVER_SETS` defaults to `common $(VALIDATION_NAME)`. For each
directory and scope, Make discovers `<scope>.json` and `<scope>.xdc`.
Callers can extend either list for their own configuration hierarchy.
Explicit `VALIDATION_WAIVERS` and `VALIDATION_WAIVER_TCL` lists override
discovery. CLI equivalents are repeated `--waivers` and `--waiver-tcl`
arguments. This permits distinct waivers for different builds using the
same source design, as well as shared exceptions.

Use Vivado `create_waiver` commands in XDC files for CDC, DRC, and methodology.
Scope them to reviewed paths or objects, with an owner and explanation.
Files are loaded into the validation session without modifying the saved
checkpoint. Waived CDC findings and native waiver accounting are reported
separately.

For critical-warning messages and constraint-coverage exceptions, use JSON:

```json
{
  "waivers": [
    {
      "name": "reviewed-message",
      "category": "critical_warnings",
      "id": "EXAMPLE-1",
      "source": "synthesis",
      "detail": "Exact reviewed warning text",
      "builds": ["accelerator-a"],
      "max_count": 1,
      "reason": "Explain why the reviewed condition is acceptable."
    }
  ]
}
```

Category and ID match exactly. `detail` and `source` are Python regular
expressions matched against the complete field; message continuations are
retained. `max_count` bounds the total matched findings. Identical messages
within a source count once. The optional `builds` list restricts a waiver
to exact build names. Names must be unique and rationale is required.
Unused JSON waivers are reported.

Constraint exceptions use category `constraints`, a `check_timing` ID such
as `no_clock`, an empty source, and the complete section detail. The count
is the number of affected objects. Identify the reviewed objects and set
a count limit that exposes newly affected objects. JSON cannot waive
timing, routing, or integrity failures.

Run the regression suite from the library root:

```sh
python3 -B -m unittest discover -s scripts/tests
```
