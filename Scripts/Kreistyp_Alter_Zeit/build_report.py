"""Deutschen Gesamtbericht und ergänzende Abbildungsgalerie erstellen."""
from pathlib import Path
import base64
import html
import shutil
import subprocess
import platform

projekt = Path(__file__).resolve().parents[2]
ordner = projekt / 'results/Kreistyp_Alter_Zeit'
bericht = projekt / 'reports/Kreistyp_Alter_Zeit_Zusammenfassung.md'
stil = projekt / 'Scripts/Kreistyp_Alter_Zeit/bericht.css'
pandoc = shutil.which('pandoc')
if not pandoc:
    architektur = 'aarch64' if platform.machine() == 'arm64' else 'x86_64'
    kandidat = Path('/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools') / architektur / 'pandoc'
    if kandidat.exists():
        pandoc = str(kandidat)
if not pandoc:
    raise SystemExit('Pandoc nicht gefunden. Markdown und PNG-Dateien bleiben direkt lesbar.')
text = bericht.read_text(encoding='utf-8').replace('../results/Kreistyp_Alter_Zeit/', '').replace('(Kreistyp_Alter_Zeit_Methoden.md)', '(../../reports/Kreistyp_Alter_Zeit_Methoden.md)')
subprocess.run([pandoc, '--from=gfm', '--to=html5', '--standalone', '--embed-resources',
                '--metadata=lang:de', '--metadata=pagetitle:COVID-19 – Integrierter Analysebericht',
                '--toc', '--toc-depth=2', '--metadata=toc-title:Inhalt',
                '--include-after-body', str(projekt / 'Scripts/Kreistyp_Alter_Zeit/bericht_interaktion.html'),
                '--css', str(stil), '--resource-path', str(ordner),
                '--output', str(ordner / 'Bericht.html')], input=text, text=True, check=True, cwd=ordner)
abschnitte = []
for bilddatei in sorted(ordner.glob('*.png')):
    bild = base64.b64encode(bilddatei.read_bytes()).decode()
    titel = bilddatei.stem.replace('_', ' ')
    abschnitte.append(f'<section><h2>{html.escape(titel)}</h2>'
                      f'<img src="data:image/png;base64,{bild}" alt="{html.escape(titel)}"></section>')
seite = ('<!doctype html><html lang="de"><meta charset="utf-8"><title>COVID-19: Abbildungen</title>'
         f'<style>{stil.read_text()}</style><main><h1>COVID-19: ergänzende Abbildungen</h1>'
         '<p>Vollständige Galerie einschließlich ergänzender Altersansichten. '
         'Die interpretierte Auswahl steht im <a href="Bericht.html">Gesamtbericht</a>.</p>'
         + ''.join(abschnitte) + '</main></html>')
(ordner / 'Abbildungen.html').write_text(seite, encoding='utf-8')
print('Deutscher Bericht und vollständige Galerie gespeichert:', ordner)
