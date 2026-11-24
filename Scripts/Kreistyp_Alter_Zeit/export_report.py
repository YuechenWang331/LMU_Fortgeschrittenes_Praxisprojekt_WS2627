"""Portablen deutschen Bericht samt Abbildungen und Ergebnistabellen exportieren."""
from pathlib import Path
import argparse
import hashlib
import json
import platform
import re
import shutil
import subprocess
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('ziel', type=Path, help='Ausgabeordner für das Berichtspaket')
args = parser.parse_args()
projekt = Path(__file__).resolve().parents[2]
quelle = projekt / 'results/Kreistyp_Alter_Zeit'
ziel = args.ziel.resolve()
material = ziel / 'Material'
material.mkdir(parents=True, exist_ok=True)
def aktiv(name):
    return not name.startswith(('15_panel_', '16_spatial_', 'panel_', 'spatial_', 'model_', 'MODEL_VALIDATION'))
for alt in material.iterdir():
    if alt.is_file() and not aktiv(alt.name):
        alt.unlink()
text = (projekt / 'reports/Kreistyp_Alter_Zeit_Zusammenfassung.md').read_text()
bilder = re.findall(r'!\[[^\]]*\]\(\.\./results/Kreistyp_Alter_Zeit/([^)]*)\)', text)
manifest = {
    'hauptabbildungen': bilder,
    'eingabe_md5': hashlib.md5((projekt / 'data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds').read_bytes()).hexdigest(),
    'abbildungen': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(quelle.glob('*.png')) if aktiv(p.name)},
}
(quelle / 'figure_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
for datei in quelle.iterdir():
    if not aktiv(datei.name):
        continue
    if datei.suffix in {'.png', '.pdf', '.csv', '.json'} or datei.name in {
        'VALIDATION.txt', 'EXTENDED_VALIDATION.txt', 'TIME_SERIES_VALIDATION.txt'
    }:
        shutil.copy2(datei, material / datei.name)
text = text.replace('../results/Kreistyp_Alter_Zeit/', 'Material/').replace('(Kreistyp_Alter_Zeit_Methoden.md)', '(Methoden.md)')
(ziel / 'Bericht.md').write_text(text)
shutil.copy2(projekt / 'reports/Kreistyp_Alter_Zeit_Methoden.md', ziel / 'Methoden.md')
for link in re.findall(r'\]\(([^)]+)\)', text):
    if not link.startswith(('http:', 'https:', '#')):
        assert (ziel / link).exists(), link
pandoc = shutil.which('pandoc')
if not pandoc:
    arch = 'aarch64' if platform.machine() == 'arm64' else 'x86_64'
    pandoc = str(Path('/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools') / arch / 'pandoc')
subprocess.run([pandoc, 'Bericht.md', '--from=gfm', '--to=html5', '--standalone', '--embed-resources',
                '--metadata=lang:de', '--metadata=pagetitle:COVID-19 – Gesamtbericht',
                '--toc', '--toc-depth=2', '--metadata=toc-title:Inhalt',
                '--css', str(projekt / 'Scripts/Kreistyp_Alter_Zeit/bericht.css'),
                '--include-after-body', str(projekt / 'Scripts/Kreistyp_Alter_Zeit/bericht_interaktion.html'),
                '--output', 'Bericht.html'], cwd=ziel, check=True)
subprocess.run([pandoc, 'Methoden.md', '--from=gfm', '--to=html5', '--standalone', '--embed-resources',
                '--metadata=lang:de', '--metadata=pagetitle:COVID-19 – Methoden',
                '--css', str(projekt / 'Scripts/Kreistyp_Alter_Zeit/bericht.css'), '--output', 'Methoden.html'], cwd=ziel, check=True)
html = (ziel / 'Bericht.html').read_text().replace('href="Methoden.md"', 'href="Methoden.html"')
(ziel / 'Bericht.html').write_text(html)
(ziel / 'Lesen.txt').write_text('Bericht.html im Browser öffnen. Abbildungen lassen sich anklicken und vergrößern.\nBericht.md und Methoden.md enthalten die bearbeitbaren Texte. Material enthält PNG, PDF und Ergebnistabellen.\n')
with zipfile.ZipFile(ziel.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED) as archiv:
    for datei in sorted(ziel.rglob('*')):
        if datei.is_file():
            archiv.write(datei, datei.relative_to(ziel.parent))
print(f'Export geprüft: {len(bilder)} Hauptabbildungen, {len(manifest["abbildungen"])} PNG-Abbildungen insgesamt; {ziel}')
