# Abbildungen aus den geprüften Ergebnistabellen neu erstellen.
# Aufruf im Projektverzeichnis: source('Scripts/Kreistyp_Alter_Zeit/abbildungen.R')
abbildungen_erstellen <- function() {
  suppressPackageStartupMessages(library(data.table))
  suppressPackageStartupMessages(library(ggplot2))
  ordner <- 'results/Kreistyp_Alter_Zeit'
  lesen <- function(datei) fread(file.path(ordner,datei))
  wochen <- lesen('weekly_district_rates.csv')
  anteile <- lesen('age_composition.csv')
  vergleiche <- lesen('pairwise_contrasts.csv')
  differenzen <- lesen('weekly_pairwise_differences.csv')
  alter <- c('0-5','6-17','18-39','40-59','60-69','70-79','80+')
  altersnamen <- c('0–5','6–17','18–39','40–59','60–69','70–79','80+')
  altersfarben <- setNames(c('#704494','#D85C00','#0072B2','#008269','#A87500','#B13C80','#323A40'),alter)
  typen <- c('Großstädte','Städtische Kreise','Ländlich, verdichtet','Ländlich, dünn besiedelt')
  typfarben <- setNames(c('#176B9A','#168477','#D27822','#9B548C'),typen)
  paare <- c('1 - 2','1 - 3','1 - 4','2 - 3','2 - 4','3 - 4')
  paarnamen <- c('Großstädte − städtische Kreise','Großstädte − ländlich, verdichtet',
    'Großstädte − ländlich, dünn besiedelt','Städtische Kreise − ländlich, verdichtet',
    'Städtische Kreise − ländlich, dünn besiedelt','Ländlich, verdichtet − dünn besiedelt')
  phasen <- c('P0','W1','G1','W2','W3','G2','W4','W5','PostW5')
  phasennamen <- c('Vor W1','W1','Zwischen\nW1/W2','W2','W3','Zwischen\nW3/W4','W4','W5','Nach W5*')
  zahlen <- function(x) format(x,big.mark='.',decimal.mark=',',trim=TRUE,scientific=FALSE)
  altersskala <- function() scale_color_manual(values=altersfarben,breaks=alter,labels=altersnamen,name='Alter (Jahre)')
  zeitskala <- function() scale_x_date(breaks=as.Date(paste0(2020:2023,'-01-01')),date_labels='%Y',
    limits=as.Date(c('2019-12-30','2023-12-31')),expand=expansion(mult=c(.005,.015)))
  grund <- theme_minimal(base_size=12,base_family='sans')+
    theme(plot.title=element_text(face='bold',size=19,color='#174B57',margin=margin(b=8)),
      plot.subtitle=element_text(size=11.5,color='#50616A',margin=margin(b=16),lineheight=1.15),
      plot.title.position='plot',plot.caption.position='plot',
      plot.caption=element_text(size=9,color='#64737A',hjust=0,lineheight=1.2,margin=margin(t=15)),
      plot.margin=margin(18,24,15,18),panel.grid.minor=element_blank(),
      panel.grid.major.x=element_blank(),panel.grid.major.y=element_line(color='#E5EBED',linewidth=.35),
      strip.text=element_text(face='bold',size=11,color='#214C57',hjust=0),
      strip.background=element_rect(fill='#EDF4F5',color=NA),
      panel.spacing=grid::unit(1.3,'lines'),legend.position='top',legend.justification='left',
      legend.title=element_text(size=10,face='bold'),legend.text=element_text(size=10),
      axis.title=element_text(color='#42545D',size=11),axis.text=element_text(color='#42545D',size=10))
  fuss <- '383 Kreise mit vollständigen Nennern · gleiche Kreisgewichte · jährliche Kreistypzuordnung'
  speichern <- function(name,grafik,breite=12,hoehe=8) {
    ggsave(file.path(ordner,paste0(name,'.png')),grafik+grund,width=breite,height=hoehe,dpi=220,bg='white')
    ggsave(file.path(ordner,paste0(name,'.pdf')),grafik+grund,width=breite,height=hoehe,device=function(filename,...) grDevices::quartz(file=filename,type='pdf',...),bg='white')
  }
  wochen[,typ:=factor(type,1:4,typen)]
  wochen[,altersgruppe:=factor(outcome,alter,altersnamen)]
  gesamt <- wochen[outcome %in% c('crude','standard')]
  gesamt[,verfahren:=factor(outcome,c('crude','standard'),c('Beobachtete Altersstruktur','Einheitliche Altersstruktur'))]
  grafik <- ggplot(gesamt,aes(week_start,mean,color=typ))+geom_line(linewidth=.7)+
    facet_wrap(~verfahren,ncol=1)+scale_color_manual(values=typfarben,name=NULL)+zeitskala()+
    scale_y_continuous(labels=zahlen)+guides(color=guide_legend(nrow=1))+
    labs(title='Bleiben die Unterschiede nach Altersstandardisierung bestehen?',
      subtitle='Mittlere wöchentliche Meldeinzidenz nach Kreistyp · 2020–2023',
      x=NULL,y='Gemeldete Fälle je 100.000 Personen und Woche',
      caption=paste(fuss,'\nGemeinsame Altersgewichte: RKI-inferierte Bevölkerung 2021; bekannte Altersgruppen.'))
  speichern('01_crude_standard_weekly',grafik,13,8)
  grafik <- ggplot(wochen[outcome %in% alter],aes(week_start,mean,color=typ))+
    geom_line(linewidth=.6)+facet_wrap(~altersgruppe,ncol=2)+
    scale_color_manual(values=typfarben,name=NULL)+zeitskala()+scale_y_continuous(labels=zahlen)+
    labs(title='Der zeitliche Verlauf unterscheidet sich nach Alter',
      subtitle='Sieben Altersgruppen · identische Skalen ermöglichen den Vergleich absoluter Größen',
      x=NULL,y='Gemeldete Fälle je 100.000 Personen der Altersgruppe und Woche',caption=fuss)
  speichern('02_age_weekly',grafik,13,11)
  anteile[,typ:=factor(type,4:1,rev(typen))]
  anteile[,altersgruppe:=factor(age_group,alter)]
  grafik <- ggplot(anteile,aes(typ,mean_share,fill=altersgruppe))+
    geom_col(position=position_stack(reverse=TRUE),width=.68)+
    geom_text(aes(label=paste0(formatC(mean_share*100,format='f',digits=0),' %')),
      position=position_stack(vjust=.5,reverse=TRUE),size=3,color='white',fontface='bold')+
    coord_flip()+facet_wrap(~iso_year,ncol=2)+theme(panel.spacing.x=grid::unit(1.7,'cm'))+
    guides(fill=guide_legend(nrow=1))+
    scale_fill_manual(values=altersfarben,breaks=alter,labels=altersnamen,name='Alter (Jahre)')+
    scale_y_continuous(labels=function(x) paste0(x*100,' %'),expand=expansion(mult=c(.02,.03)))+
    labs(title='Unterschiedliche Altersstrukturen der Kreistypen',
      subtitle='Durchschnittlicher Bevölkerungsanteil je Kreis; jeder Balken entspricht 100 %',
      x=NULL,y=NULL,caption=paste(fuss,'\nRKI-inferierte Nenner, keine unabhängige amtliche Bevölkerungsstatistik. Beschriftungen gerundet.'))
  speichern('03_age_composition',grafik,14,8)
  vergleiche[,paar:=factor(paste(type_a,type_b,sep=' - '),paare,paarnamen)]
  gesamt <- vergleiche[period=='All' & outcome %in% c('crude','standard') & scale=='absolute']
  gesamt[,paar:=factor(as.character(paar),rev(paarnamen))]
  gesamt[,verfahren:=factor(outcome,c('crude','standard'),c('Beobachtete Altersstruktur','Altersstandardisiert'))]
  verschiebung <- position_dodge(width=.45)
  grafik <- ggplot(gesamt,aes(estimate,paar,color=verfahren))+
    geom_vline(xintercept=0,color='#819198',linetype='dashed')+
    geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.12,position=verschiebung,linewidth=.7)+
    geom_point(position=verschiebung,size=2.7)+
    scale_color_manual(values=c('#9C9FA2','#087F8C'),name=NULL)+
    labs(title='Wie groß ist der durchschnittliche Unterschied?',
      subtitle='Alle sechs Paarvergleiche · mittlere wöchentliche Differenz über 2020–2023',
      x='Erstgenannter minus zweitgenannter Kreistyp: Fälle je 100.000 und Woche',y=NULL,
      caption='Punkte: Schätzung · Linien: punktweise 95%-Konfidenzintervalle (nicht multiplikitätskorrigiert)\nStatistische Bewertung: Holm-korrigierte p-Werte in der Ergebnistabelle; 1.999 Kreis-Bootstrap-Stichproben.')
  speichern('04_overall_absolute',grafik,14,7)
  relativ <- vergleiche[period=='All' & outcome %in% alter & scale=='relative']
  relativ[,altersgruppe:=factor(outcome,rev(alter),rev(altersnamen))]
  relativ[,paar:=factor(as.character(paar),paarnamen,gsub(' − ',' / ',paarnamen,fixed=TRUE))]
  grafik <- ggplot(relativ,aes(estimate,altersgruppe))+
    geom_vline(xintercept=1,color='#819198',linetype='dashed')+
    geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.12,color='#5F8D97',linewidth=.65)+
    geom_point(size=2.4,color='#155B6C')+facet_wrap(~paar,ncol=2)+
    scale_x_log10(breaks=c(.85,.90,.95,1,1.05),labels=function(x) formatC(x,format='f',digits=2,decimal.mark=','))+
    labs(title='Relative Unterschiede innerhalb der Altersgruppen',
      subtitle='Verhältnis der mittleren Wochenraten · 1 = gleiche Rate · 0,90 = 10 % niedrigere Rate',
      x='Erstgenannter / zweitgenannter Kreistyp (logarithmische Skala)',y='Alter (Jahre)',
      caption='2020–2023 · Punktweise 95%-Konfidenzintervalle; statistische Bewertung mit Holm-Korrektur separat.\nUnterschiedliche Signifikanz einzelner Altersgruppen ist noch kein Nachweis einer Altersinteraktion.')
  speichern('05_age_relative',grafik,14,10)
  kacheln <- vergleiche[period!='All' & outcome %in% alter & scale=='absolute']
  kacheln[,`:=`(phase=factor(period,phasen,phasennamen),altersgruppe=factor(outcome,rev(alter),rev(altersnamen)))]
  grenze <- ceiling(max(abs(kacheln$estimate))/50)*50
  grafik <- ggplot(kacheln,aes(phase,altersgruppe,fill=estimate))+
    geom_tile(color='white',linewidth=.65)+
    geom_text(aes(label=round(estimate),color=abs(estimate)>grenze*.6),size=3)+
    scale_color_manual(values=c('FALSE'='#304047','TRUE'='white'),guide='none')+
    facet_wrap(~paar,ncol=2)+scale_fill_gradient2(low='#633D91',mid='#FAFAFA',high='#C85D27',
      limits=c(-grenze,grenze),breaks=c(-grenze,0,grenze),name='Differenz')+
    guides(fill=guide_colourbar(barwidth=grid::unit(8,'cm'),barheight=grid::unit(.35,'cm')))+
    labs(title='Wann sind die altersabhängigen Unterschiede besonders groß?',
      subtitle='Mittlere wöchentliche Differenz je Zeitraum · violett: erstgenannter Kreistyp niedriger',
      x=NULL,y='Alter (Jahre)',caption='W1–W5: bestehende RKI-Welleneinteilung; Zwischenräume bleiben enthalten. Zahlen: gerundete Differenzen je 100.000.\n* Nach W5: KW 22/2022–KW 52/2023, keine einzelne Welle. Farben zeigen Effektgrößen, keine Signifikanz.')
  speichern('06_age_period_absolute',grafik,15,11)
  differenzen[,paar:=factor(pair,paare,paarnamen)]
  grafik <- ggplot(differenzen[outcome %in% alter],aes(week_start,difference,color=outcome))+
    geom_hline(yintercept=0,color='#819198',linewidth=.4)+geom_line(linewidth=.55)+
    facet_wrap(~paar,ncol=2)+altersskala()+guides(color=guide_legend(nrow=1))+zeitskala()+scale_y_continuous(labels=zahlen)+
    labs(title='Die Richtung der Unterschiede kann sich umkehren',
      subtitle='Wöchentliche Paarvergleiche · oberhalb von 0: erstgenannter Kreistyp höher; unterhalb von 0: niedriger',
      x=NULL,y='Differenz je 100.000 Personen der Altersgruppe und Woche',
      caption=paste(fuss,'\nDeskriptive Wochenwerte ohne wöchentliche Signifikanztests; ein Vorzeichenwechsel allein ist kein statistischer Nachweis.'))
  speichern('07_weekly_pairwise_differences',grafik,14,10)
  message('Sieben Abbildungen als PNG und PDF gespeichert: ',ordner)
}
abbildungen_erstellen()
