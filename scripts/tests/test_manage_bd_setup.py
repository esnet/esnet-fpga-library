"""Check BD synthesis setup and cache invalidation without Vivado."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

MANAGER = Path(__file__).resolve().parents[1] / 'vivado/manage_bd.tcl'


class BdSynthesisSetupTests(unittest.TestCase):
    def run_manager(self, existing=True, hook=True, newer=False, missing=False, registered=True, changes=False, complete=True, checkpoint_missing=False, needs_refresh=False):
        tmp = tempfile.TemporaryDirectory(prefix='bd-hook-')
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        (root / 'design').mkdir()
        (root / 'design/design.bd').write_text('block design')
        hook_path = root / 'hook with spaces.tcl'
        if not missing:
            hook_path.write_text('puts CONFIGURED\nif {!$::generated} {error {Setup ran before generation}}\nif {$bd ne {design} || $synth_run ne {design_synth_1}} {error {Missing setup context}}\n' + ('set ::needs_refresh 1\n' if changes else ''))
        checkpoint = root / 'design.dcp'
        checkpoint.write_text('checkpoint')
        if not missing:
            age = checkpoint.stat().st_mtime_ns + (2_000_000_000 if newer else -2_000_000_000)
            os.utime(hook_path, ns=(age, age))
        if checkpoint_missing:
            checkpoint.unlink()
        requested = str(hook_path) if hook else ''
        args = ['synth', '-bd', 'design', '-bd_file', str(root / 'design/design.bd'),
                '-proj_dir', str(root), '-synth_setup_tcl', requested]
        driver = root / 'driver.tcl'
        driver.write_text('''
set argv {@ARGS@}
set argc [llength $argv]
set exists @EXISTS@
set registered @REGISTERED@
set needs_refresh @REFRESH@
set run_status {@STATUS@}
set generated @EXISTS@
set directory {@ROOT@}
cd $directory
namespace eval vivadoProcs {
 proc open_proj {args} {puts OPEN}
 proc close_proj {} {puts CLOSE}
 proc set_top {args} {}
 proc config_synth_run {args} {}
}
proc get_property {name object} {
 switch $name {
  ip_repo_paths {return {}}
  STATUS {return $::run_status}
  NEEDS_REFRESH {return $::needs_refresh}
  DIRECTORY {return $::directory}
  default {error "Unexpected property $name"}
 }
}
proc get_runs {name} {if {$::exists} {return $name}; return {}}
proc get_bd_designs {args} {return {}}
proc read_bd {args} {set ::registered 1; puts BD_IMPORTED}
proc update_ip_catalog {} {}
proc get_files {args} {if {$::registered} {return design.bd}; return {}}
proc current_project {} {return project}
proc reset_target {args} {puts RESET_TARGET}
proc generate_target {args} {set ::generated 1; puts GENERATE}
proc reset_run {args} {set ::needs_refresh 0; puts RESET_RUN}
proc create_run {args} {set ::exists 1; puts CREATE_RUN}
proc launch_runs {args} {puts LAUNCH}
proc wait_on_runs {args} {puts WAIT}
source {@MANAGER@}
'''.replace('@ARGS@', ' '.join('{' + a + '}' for a in args)).replace('@EXISTS@', str(int(existing)))
            .replace('@REFRESH@', str(int(needs_refresh))).replace('@STATUS@', 'synth_design Complete!' if complete else 'synth_design ERROR').replace('@REGISTERED@', str(int(registered))).replace('@ROOT@', str(root)).replace('@MANAGER@', str(MANAGER)))
        result = subprocess.run(['tclsh', str(driver)], text=True, capture_output=True)
        return result, requested

    def test_new_run_configures_products_before_launch(self):
        result, hook = self.run_manager(existing=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('LAUNCH', result.stdout)
        self.assertLess(result.stdout.index('GENERATE'), result.stdout.index('CONFIGURED'))
        self.assertLess(result.stdout.index('CONFIGURED'), result.stdout.index('LAUNCH'))
        self.assertIn('CREATE_RUN', result.stdout)

    def test_default_and_unchanged_setup_preserve_cached_runs(self):
        for hook in (False, True):
            with self.subTest(hook=hook):
                result, _ = self.run_manager(hook=hook)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('up to date', result.stdout)
                self.assertNotIn('RESET_RUN', result.stdout)
                self.assertNotIn('LAUNCH', result.stdout)
                self.assertNotIn('WAIT', result.stdout)
                self.assertEqual(result.stdout.count('CONFIGURED'), int(hook))

    def test_changed_settings_and_modified_scripts_invalidate_the_run(self):
        for settings in (dict(changes=True), dict(newer=True)):
            with self.subTest(settings=settings):
                result, hook = self.run_manager(**settings)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('RESET_RUN', result.stdout)
                if settings.get('newer'):
                    self.assertIn('GENERATE', result.stdout)
                self.assertIn('LAUNCH', result.stdout)

    def test_failed_runs_and_missing_checkpoints_are_rebuilt(self):
        for settings in (dict(complete=False), dict(checkpoint_missing=True), dict(needs_refresh=True)):
            with self.subTest(settings=settings):
                result, _ = self.run_manager(hook=False, **settings)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('RESET_RUN', result.stdout)
                self.assertIn('GENERATE', result.stdout)
                self.assertIn('LAUNCH', result.stdout)
                self.assertIn('WAIT', result.stdout)

    def test_closed_diagrams_are_not_added_to_the_fileset_again(self):
        result, _ = self.run_manager(hook=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('BD_IMPORTED', result.stdout)
        result, _ = self.run_manager(hook=False, registered=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('BD_IMPORTED'), 1)

    def test_missing_setup_fails_before_opening_project(self):
        result, _ = self.run_manager(missing=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Missing BD synthesis setup script', result.stderr)
        self.assertNotIn('OPEN', result.stdout)


if __name__ == '__main__':
    unittest.main()
