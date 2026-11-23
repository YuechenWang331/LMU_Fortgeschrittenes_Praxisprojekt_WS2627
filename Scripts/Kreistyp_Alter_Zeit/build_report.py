"""Eine eigenständige deutschsprachige Abbildungsgalerie erstellen."""
from pathlib import Path
import base64
import html

projekt = Path(__file__).resolve().parents[2]
ordner = projekt / 'results/Kreistyp_Alter_Zeit'
abbildungen = [
 ('01_crude_standard_weekly', 'Gesamtverlauf vor und nach Altersstandardisierung'),
 ('02_age_weekly', 'Zeitverläufe innerhalb der Altersgruppen'),
 ('03_age_composition', 'Alterszusammensetzung der Kreistypen'),
 ('04_overall_absolute', 'Absolute Unterschiede im gesamten Zeitraum'),
 ('05_age_relative', 'Relative Unterschiede nach Alter'),
 ('06_age_period_absolute', 'Altersabhängige Unterschiede nach Zeitraum'),
 ('07_weekly_pairwise_differences', 'Wöchentliche Unterschiede und Richtungswechsel'),
]
abschnitte = []
for nummer, (dateiname, titel) in enumerate(abbildungen, 1):
    bild = base64.b64encode((ordner / (dateiname + '.png')).read_bytes()).decode()
    abschnitte.append(f'<h2>{nummer}. {html.escape(titel)}</h2>'
                      f'<img src="data:image/png;base64,{bild}" alt="{html.escape(titel)}">')
stil = 'body{font-family:Arial,sans-serif;max-width:1300px;margin:40px auto;padding:20px;color:#26434d}h1,h2{color:#155867}img{width:100%;height:auto}h2{margin-top:50px}p{line-height:1.6}'
seite = ('<!doctype html><html lang="de"><meta charset="utf-8"><title>COVID-19: Abbildungen</title>'
         f'<style>{stil}</style><h1>COVID-19: Kreistyp, Alter und Zeit</h1>'
         '<p>383 vollständig beobachtete Kreise; gleiche Kreisgewichte. '
         'Konfidenzintervalle sind punktweise; Holm-korrigierte Tests stehen in den Ergebnistabellen. '
         'Die vollständige Erläuterung enthält reports/Kreistyp_Alter_Zeit_Zusammenfassung.md.</p>'
         + ''.join(abschnitte) + '</html>')
(ordner / 'Abbildungen.html').write_text(seite, encoding='utf-8')
print('Abbildungsgalerie gespeichert:', ordner / 'Abbildungen.html')
