#!/usr/bin/env python3
"""Create visual comparison artifacts and measure mean 5x5 sRGB probes.

Usage: compare.sh DEVICE.png REFERENCE.png PROBES.json OUT_DIR
Reference is content only, width 1170px; coordinates are in 390pt space.
Device is a full screenshot; crop 47pt status bar and 34pt bottom inset.
FIDELITY_CONTENT_INPUT=1 accepts an already cropped content image (self-test).
FIDELITY_SCREEN=library|collections|capture overrides filename inference.
Probe differences are reported, never used as the weighted checklist score.
Exit 0 means analysis completed (even if colors differ); exit 2 means invalid input.
"""
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import sys


def run(*args):
    return subprocess.run([str(a) for a in args], check=True, capture_output=True, text=True).stdout.strip()


def lab(rgb):
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb]
    r, g, b = linear
    xyz = [(0.4124564*r + 0.3575761*g + 0.1804375*b)/0.95047,
           0.2126729*r + 0.7151522*g + 0.0721750*b,
           (0.0193339*r + 0.1191920*g + 0.9503041*b)/1.08883]
    x, y, z = [v ** (1/3) if v > (6/29)**3 else v/(3*(6/29)**2)+4/29 for v in xyz]
    return 116*y-16, 500*(x-y), 200*(y-z)


def delta_e(a, b):
    """CIEDE2000, unit parametric factors; angles in degrees."""
    l1, a1, b1 = a
    l2, a2, b2 = b
    c1, c2 = math.hypot(a1, b1), math.hypot(a2, b2)
    cm = (c1+c2)/2
    g = 0.5*(1-math.sqrt(cm**7/(cm**7+25**7)))
    ap1, ap2 = (1+g)*a1, (1+g)*a2
    cp1, cp2 = math.hypot(ap1, b1), math.hypot(ap2, b2)
    hp1, hp2 = math.degrees(math.atan2(b1, ap1)) % 360, math.degrees(math.atan2(b2, ap2)) % 360
    dl, dc = l2-l1, cp2-cp1
    dh = hp2-hp1
    if cp1*cp2 == 0:
        dh = 0
    elif dh > 180:
        dh -= 360
    elif dh < -180:
        dh += 360
    d_h = 2*math.sqrt(cp1*cp2)*math.sin(math.radians(dh/2))
    lm, cpm = (l1+l2)/2, (cp1+cp2)/2
    if cp1*cp2 == 0:
        hm = hp1+hp2
    elif abs(hp1-hp2) <= 180:
        hm = (hp1+hp2)/2
    elif hp1+hp2 < 360:
        hm = (hp1+hp2+360)/2
    else:
        hm = (hp1+hp2-360)/2
    cos = lambda angle: math.cos(math.radians(angle))
    t = 1-0.17*cos(hm-30)+0.24*cos(2*hm)+0.32*cos(3*hm+6)-0.20*cos(4*hm-63)
    sl = 1+0.015*(lm-50)**2/math.sqrt(20+(lm-50)**2)
    sc, sh = 1+0.045*cpm, 1+0.015*cpm*t
    rt = -2*math.sqrt(cpm**7/(cpm**7+25**7))*math.sin(math.radians(60*math.exp(-((hm-275)/25)**2)))
    return math.sqrt((dl/sl)**2+(dc/sc)**2+(d_h/sh)**2+rt*(dc/sc)*(d_h/sh))


def dimensions(path):
    return tuple(map(int, run('magick', 'identify', '-format', '%w %h', path).split()))


def sample(path, x, y):
    # Mean in sRGB, exactly the same 5x5 sampling as reference probes.
    value = run('magick', path, '-crop', f'5x5+{x-2}+{y-2}', '+repage',
                '-colorspace', 'sRGB', '-scale', '1x1!', '-depth', '8', '-format', '%[hex:p{0,0}]', 'info:')
    value = value[:6]
    return '#'+value, tuple(int(value[i:i+2], 16)/255 for i in (0, 2, 4))


def main():
    if len(sys.argv) == 2 and sys.argv[1] in ('-h', '--help'):
        print(__doc__)
        return
    if len(sys.argv) != 5:
        raise ValueError(__doc__)
    device, reference, probes_path = map(Path, sys.argv[1:4])
    out = Path(sys.argv[4])
    if not shutil.which('magick'):
        raise ValueError('ImageMagick 7 (magick) is required')
    for path in (device, reference, probes_path):
        if not path.is_file():
            raise ValueError(f'Input not found: {path}')
    screen = os.environ.get('FIDELITY_SCREEN', reference.stem.removeprefix('v3-'))
    config = json.loads(probes_path.read_text())
    probes = config['screens'][screen]['probes']
    rw, rh = dimensions(reference)
    if rw != 1170:
        raise ValueError(f'Reference width must be 1170, got {rw}')
    dw, dh = dimensions(device)
    content = os.environ.get('FIDELITY_CONTENT_INPUT') == '1'
    top, bottom = (0, 0) if content else (round(dw*47/390), round(dw*34/390))
    if dh <= top+bottom:
        raise ValueError('Device image shorter than status and home insets')
    normalized_h = round((dh-top-bottom)*1170/dw)
    if normalized_h < rh:
        raise ValueError(f'Device content height {normalized_h}px is shorter than reference {rh}px')
    for probe in probes:
        px, py = round(probe['x']*3), round(probe['y']*3)
        if not (2 <= px < rw-2 and 2 <= py < rh-2):
            raise ValueError(f'Probe outside content: {probe["id"]}')
    out.mkdir(parents=True, exist_ok=True)
    normalized = out/'device-content.png'
    run('magick', device, '-crop', f'{dw}x{dh-top-bottom}+0+{top}', '+repage',
        '-resize', '1170x', '-gravity', 'NorthWest', '-crop', f'{rw}x{rh}+0+0', '+repage', normalized)
    run('magick', reference, normalized, '+append', out/'side-by-side.png')
    run('magick', reference, normalized, '-compose', 'blend', '-define', 'compose:args=50,50', '-composite', out/'overlay.png')
    run('magick', reference, normalized, '-compose', 'difference', '-composite', out/'diff.png')
    ssim = subprocess.run(['magick', 'compare', '-metric', 'SSIM', str(reference), str(normalized), 'null:'], capture_output=True, text=True)
    if ssim.returncode not in (0, 1):
        raise ValueError(f'SSIM failed: {ssim.stderr}')
    rows = []
    for probe in probes:
        actual, rgb = sample(normalized, round(probe['x']*3), round(probe['y']*3))
        expected = probe['hex'].lstrip('#')
        expected_rgb = tuple(int(expected[i:i+2], 16)/255 for i in (0, 2, 4))
        difference = delta_e(lab(rgb), lab(expected_rgb))
        tolerance = probe.get('tolerance', 3)
        rows.append(dict(id=probe['id'], expected='#'+expected, actual=actual,
                         deltaE2000=round(difference, 4), tolerance=tolerance, passed=difference <= tolerance))
    report = dict(screen=screen, metric='CIEDE2000 (sRGB D65, mean 5x5 pixels)',
                  ssim=ssim.stderr.strip(), ssimInterpretation='ImageMagick SSIM distortion: 0 means identical; informational only', deviceCrop=dict(topPixels=top, bottomPixels=bottom),
                  comparedSize=[rw, rh], probes=rows)
    (out/'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    print(f'Screen: {screen}; ImageMagick SSIM distortion (0 identical): {report["ssim"]}')
    print('Probe\tExpected\tActual\tDeltaE2000\tResult')
    for row in rows:
        print(f'{row["id"]}\t{row["expected"]}\t{row["actual"]}\t{row["deltaE2000"]:.4f}\t'+('PASS' if row['passed'] else 'FAIL'))
    print(f'Colors: {sum(row["passed"] for row in rows)}/{len(rows)}; artifacts: {out}')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f'compare: {error}', file=sys.stderr)
        sys.exit(2)
