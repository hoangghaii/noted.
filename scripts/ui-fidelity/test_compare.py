#!/usr/bin/env python3
"""Local harness checks: python3 -B scripts/ui-fidelity/test_compare.py."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('compare.py')
spec = importlib.util.spec_from_file_location('fidelity', SCRIPT)
fidelity = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fidelity)


class FidelityTests(unittest.TestCase):
    def test_ciede2000_reference_vectors(self):
        # Sharma/Wu/Dalal supplementary dataset, first four pairs.
        reference = (50, 0, -82.7485)
        for color, expected in [((50, 2.6772, -79.7751), 2.0425),
                                ((50, 3.1571, -77.2803), 2.8615),
                                ((50, 2.8361, -74.0200), 3.4412),
                                ((50, -1.3802, -84.2814), 1.0000)]:
            self.assertAlmostEqual(fidelity.delta_e(color, reference), expected, places=4)

    def test_crop_artifacts_probes_and_invalid_input(self):
        with tempfile.TemporaryDirectory(prefix='noted-fidelity-') as directory:
            root = Path(directory)
            reference = root/'v3-library.png'
            device = root/'device.png'
            probes = root/'probes.json'
            fidelity.run('magick', '-size', '1170x600', 'xc:#F8F3EB', reference)
            # A red status bar and blue home inset must not enter comparison.
            fidelity.run('magick', '-size', '1170x141', 'xc:red',
                         '-size', '1170x600', 'xc:#F8F3EB',
                         '-size', '1170x102', 'xc:blue', '-append', device)
            probes.write_text(json.dumps({'screens': {'library': {'probes': [
                {'id': 'match', 'x': 10, 'y': 10, 'hex': '#F8F3EB'},
                {'id': 'mismatch', 'x': 20, 'y': 20, 'hex': '#000000'}]}}}))
            out = root/'out'
            result = subprocess.run(['python3', '-B', str(SCRIPT), str(device), str(reference),
                                     str(probes), str(out)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads((out/'report.json').read_text())
            self.assertEqual(report['deviceCrop'], {'topPixels': 141, 'bottomPixels': 102})
            self.assertEqual([p['passed'] for p in report['probes']], [True, False])
            for name in ('side-by-side.png', 'overlay.png', 'diff.png', 'device-content.png'):
                self.assertTrue((out/name).is_file())
            invalid = subprocess.run(['python3', '-B', str(SCRIPT), str(reference), str(reference),
                                      str(probes), str(root/'invalid')], capture_output=True, text=True)
            self.assertEqual(invalid.returncode, 2)
            self.assertIn('shorter than reference', invalid.stderr)
            env = dict(os.environ, FIDELITY_CONTENT_INPUT='1')
            self_test = subprocess.run(['python3', '-B', str(SCRIPT), str(reference), str(reference),
                                        str(probes), str(root/'self')], env=env, capture_output=True, text=True)
            self.assertEqual(self_test.returncode, 0, self_test.stderr)


if __name__ == '__main__':
    unittest.main()
