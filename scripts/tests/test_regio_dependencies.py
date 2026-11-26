"""Check cached decoder RTL follows transitive register-map changes."""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class RegioDependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        (self.work / 'config.mk').touch()
        (self.work / 'out/rtl/src').mkdir(parents=True)
        self.leaf = self.work / 'cfg.yaml'
        self.write_regs(11)
        (self.work / 'inner_decoder.yaml').write_text('''name: inner
blocks:
  cfg: &cfg
    !include cfg.yaml
interfaces:
  - block: *cfg
    address: 0
    name: cfg
''')
        (self.work / 'outer_decoder.yaml').write_text('''name: outer
decoders:
  inner: &inner
    !include inner_decoder.yaml
interfaces:
  - decoder: *inner
    address: 0
    name: inner
''')
        (self.work / 'Makefile').write_text(f'''
SCRIPTS_ROOT := {ROOT}/scripts
REGIO_ROOT := {ROOT}/tools/regio
LIB_ROOT := {ROOT}
LIB_OUTPUT_ROOT := {self.work}
COMPONENT_ROOT_PATH := .
COMPONENT_OUT_PATH := {self.work}/out
REGIO_YAML_INC_DIR := {self.work}
COMPONENT_BASE := test
REG_BLOCK_YAML := cfg.yaml
REG_DECODER_YAML := outer_decoder.yaml
include {ROOT}/scripts/Makefiles/regio.mk
''')
        self.decoder = self.work / 'out/rtl/src/outer_decoder.sv'
        self.package = self.work / 'out/rtl/src/outer_decoder_pkg.sv'

    def write_regs(self, count):
        self.leaf.write_text('name: cfg\ninfo: Test registers.\nregs:\n' + ''.join(
            f'  - name: reg{i}\n    width: 32\n    access: ro\n' for i in range(count)))

    def generate(self):
        result = subprocess.run(['make', '-s', '_reg_rtl'], cwd=self.work,
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def window_size(self):
        return int(re.search(r"size: 'h([0-9a-f]+)", self.package.read_text())[1], 16)

    def test_transitive_block_growth_updates_decoder(self):
        self.generate()
        self.assertEqual(self.window_size(), 44)
        self.write_regs(13)
        self.generate()
        self.assertEqual(self.window_size(), 52)

    def test_unchanged_inputs_preserve_generated_rtl(self):
        self.generate()
        before = self.decoder.stat().st_mtime_ns
        self.generate()
        self.assertEqual(self.decoder.stat().st_mtime_ns, before)

    def test_cached_dependencies_follow_relocated_checkout(self):
        self.generate()
        relocated = tempfile.TemporaryDirectory()
        self.addCleanup(relocated.cleanup)
        destination = Path(relocated.name) / 'checkout'
        shutil.copytree(self.work, destination)
        makefile = destination / 'Makefile'
        makefile.write_text(makefile.read_text().replace(str(self.work), str(destination)))
        self.work = destination
        self.leaf = self.work / 'cfg.yaml'
        self.decoder = self.work / 'out/rtl/src/outer_decoder.sv'
        self.package = self.work / 'out/rtl/src/outer_decoder_pkg.sv'
        self.write_regs(13)
        self.generate()
        self.assertEqual(self.window_size(), 52)

    def test_legacy_cache_without_depfile_is_refreshed(self):
        self.generate()
        Path(str(self.decoder) + '.d').unlink()
        self.package.write_text('stale cached decoder\n')
        self.generate()
        self.assertEqual(self.window_size(), 44)
        self.assertTrue(Path(str(self.decoder) + '.d').is_file())


if __name__ == '__main__':
    unittest.main()
