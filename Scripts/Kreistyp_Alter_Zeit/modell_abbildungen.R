# Neue Modellgrafiken ohne erneute Schätzung aktualisieren.
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(patchwork)})
out<-'results/Kreistyp_Alter_Zeit'
model_results<-fread(file.path(out,'panel_age_interaction_changes.csv'))
spatial<-fread(file.path(out,'spatial_contrasts.csv'))
periods<-fread(file.path(out,'period_definitions.csv'))
# Modellkontraste sind Änderungen gegenüber W4, keine neu geschätzten Gesamtunterschiede.
focus<-model_results[type_a==1 & type_b==4 & schema %in% c('kreis','block100','block200')]
phase_labels<-c(P0='Vor W1',W1='W1',G1='Zwischen W1/W2',W2='W2',W3='W3',G2='Zwischen W3/W4',W5='W5',PostW5='Nach W5')
focus[,phase:=factor(period,rev(names(phase_labels)),rev(phase_labels))]
focus[,schema_name:=factor(schema,c('kreis','block100','block200'),c('Kreise','100-km-Blöcke','200-km-Blöcke'))]
base<-theme_minimal(base_size=12)+theme(plot.title=element_text(face='bold',color='#174B57'),legend.position='top',panel.grid.minor=element_blank())
plot_scale<-function(s) {
  f<-focus[scale==s]
  g<-ggplot(f,aes(estimate,phase,color=schema_name,shape=schema_name))+
    geom_vline(xintercept=if(s=='absolute')0 else 1,linetype=2,color='grey55')+
    geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.13,position=position_dodge(width=.6))+
    geom_point(position=position_dodge(width=.6),size=2)+scale_color_manual(values=c('#96A3A6','#087F8C','#D0582B'))+base+
    labs(title=if(s=='absolute')'Absolute Altersinteraktion: Veränderung gegenüber W4' else 'Relative Altersinteraktion: Veränderung gegenüber W4',
      subtitle='18–39 vs. 70–79 Jahre · Großstadt gegenüber ländlich dünn besiedelt',
      x=if(s=='absolute')'Differenz der Altersinteraktionen (Fälle je 100.000 und Woche)' else 'Verhältnis der Altersinteraktionen (W4 = 1)',y=NULL,color='Unsicherheit',shape='Unsicherheit',
      caption='Kreis×Alter- und Woche×Alter-Fixeffekte · jährliche Kreistypen · punktweise 95%-Intervalle\nRäumliche Blöcke erlauben Abhängigkeit zwischen Kreisen desselben Blocks; Blockgrenzen bleiben eine Annahme.')
  if(s=='relative')g<-g+scale_x_log10(breaks=c(.5,.75,1,1.25,1.5,2),labels=function(v)format(v,decimal.mark=',',trim=TRUE))
  for(ext in c('png','pdf'))ggsave(file.path(out,paste0('15_panel_changes_',s,'.',ext)),g,width=12,height=7,dpi=220,bg='white',device=if(ext=='pdf')function(filename,...)grDevices::quartz(file=filename,type='pdf',...) else 'png')
}
plot_scale('absolute');plot_scale('relative')
fs<-spatial[period=='All' & type_a==1 & type_b==4 & age_a=='18-39' & age_b=='70-79']
fs[,schema_name:=factor(schema,c('block100_shift','block200','block100','kreis'),c('100 km, Raster verschoben','200-km-Blöcke','100-km-Blöcke','Einzelne Kreise'))]
g<-ggplot(fs[scale=='absolute'],aes(estimate,schema_name))+geom_vline(xintercept=0,linetype=2,color='grey60')+
  geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15,color='#087F8C')+geom_point(size=3,color='#D0582B')+base+
  labs(title='Wie verändert räumliche Abhängigkeit die Unsicherheit?',subtitle='Gesamtzeitraum · 18–39 vs. 70–79 Jahre · Großstadt minus ländlich dünn',x='Absolute Altersinteraktion je 100.000 und Woche',y=NULL,
    caption='Identische Punktschätzung; unterschiedliche Annahmen zur Abhängigkeit. Punktweise 95%-Intervalle.\nPrimär: 100-km-Raster; 200 km und verschobenes Raster als Sensitivität. Keine Korrektur räumlicher Störfaktoren.')
g<-g+labs(title='Absolut',subtitle=NULL,caption=NULL)
g_rel<-ggplot(fs[scale=='relative'],aes(estimate,schema_name))+geom_vline(xintercept=1,linetype=2,color='grey60')+
  geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15,color='#087F8C')+geom_point(size=3,color='#D0582B')+base+
  labs(title='Relativ',x='Verhältnis der Ratenverhältnisse',y=NULL)+scale_x_continuous(labels=function(v)format(v,decimal.mark=',',trim=TRUE))+theme(axis.text.y=element_blank())
gesamt<-g+g_rel+plot_layout(widths=c(1.2,1))+plot_annotation(
  title='Räumliche Abhängigkeit: absolute Evidenz stabiler als relative',
  subtitle='18–39 vs. 70–79 Jahre · Großstadt gegenüber ländlich dünn · 2020–2023',
  caption=paste0('Punktweise 95%-Intervalle, nicht Holm-korrigiert. Relative Holm-p: 100 km = ',formatC(fs[scale=='relative' & schema=='block100',p_holm],format='f',digits=3,decimal.mark=','),'; 200 km = ',formatC(fs[scale=='relative' & schema=='block200',p_holm],format='f',digits=3,decimal.mark=','),'.\nRäumliche Blöcke ändern die Unsicherheit, nicht die Punktschätzung; sie korrigieren keine räumlichen Störfaktoren.'),theme=base)
for(ext in c('png','pdf'))ggsave(file.path(out,paste0('16_spatial_uncertainty.',ext)),gesamt,width=14,height=5.5,dpi=220,bg='white',device=if(ext=='pdf')function(filename,...)grDevices::quartz(file=filename,type='pdf',...) else 'png')
