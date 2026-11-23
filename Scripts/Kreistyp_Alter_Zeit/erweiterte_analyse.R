# Ergänzende deskriptive Analysen und vollständige Altersinteraktionen.
# Voraussetzung: run_analysis.R und validate_results.R wurden erfolgreich ausgeführt.
# Aus dem Projektstamm: sys.source('Scripts/Kreistyp_Alter_Zeit/erweiterte_analyse.R', new.env())
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(ggplot2))
suppressPackageStartupMessages(library(patchwork))
local({
  out <- 'results/Kreistyp_Alter_Zeit'
  read <- function(name) fread(file.path(out,name))
  write <- function(x,name) fwrite(x,file.path(out,name))
  ages <- c('0-5','6-17','18-39','40-59','60-69','70-79','80+')
  age_labels <- c('0–5','6–17','18–39','40–59','60–69','70–79','80+')
  types <- c('Großstädte','Städtische Kreise','Ländlich, verdichtet','Ländlich, dünn besiedelt')
  short <- c('Großstadt','Städtisch','Ländlich\nverdichtet','Ländlich\ndünn besiedelt')
  colours <- setNames(c('#D0582B','#F2C06E','#C5DAA1','#69AD55'),types)
  age_colours <- setNames(c('#7A5195','#D55E00','#0072B2','#00866A','#B47A00','#B84986','#343A40'),ages)
  pair_ids <- c('1 - 2','1 - 3','1 - 4','2 - 3','2 - 4','3 - 4')
  pair_labels <- c('Großstadt / städtisch','Großstadt / ländlich verdichtet','Großstadt / ländlich dünn',
                   'Städtisch / ländlich verdichtet','Städtisch / ländlich dünn','Ländlich verdichtet / dünn')
  phases <- read('period_definitions.csv')
  phase_labels <- c('Vor W1','W1','Zwischen W1/W2','W2','W3','Zwischen W3/W4','W4','W5','Nach W5*')
  weeks <- read('weekly_district_rates.csv')
  contrasts <- read('pairwise_contrasts.csv')
  interactions <- read('age_interactions.csv')
  x <- as.data.table(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
  missing <- fread(file.path(out,'audit_missing_denominators.csv'),colClasses=c(geo_code='character'))
  d <- x[!geo_code %in% missing$geo_code]
  d[,`:=`(age_group=as.character(age_group),type=kreistyp_code)]
  ref <- read('standard_population_2021.csv')
  d <- merge(d,ref[,.(age_group,weight)],by='age_group')
  d[,period:=NA_character_]
  for(j in seq_len(nrow(phases))) d[week_start>=phases$start[j] & week_start<=phases$end[j],period:=phases$period[j]]
  standard <- d[,.(value=sum(weight*incidence)),by=.(geo_code,geo_name,type,week_start,iso_year,period)]
  standard[,outcome:='standard']
  long <- rbindlist(list(standard,d[,.(geo_code,geo_name,type,week_start,iso_year,period,outcome=age_group,value=incidence)]),use.names=TRUE)
  stopifnot(uniqueN(long$geo_code)==383, !anyNA(long$value), !anyNA(long$period))

  # Wochenverhältnisse ohne Pseudocount; Nullraten werden explizit gekennzeichnet.
  wide <- dcast(weeks[outcome %in% c('standard',ages)],outcome+week_start+period~type,value.var='mean')
  weekly_pairs <- rbindlist(lapply(combn(1:4,2,simplify=FALSE),function(p) {
    z <- wide[,.(outcome,week_start,period,type_a=p[1],type_b=p[2],rate_a=get(as.character(p[1])),rate_b=get(as.character(p[2])))]
    z[,`:=`(difference=rate_a-rate_b,ratio=ifelse(rate_b>0,rate_a/rate_b,NA_real_),
      ratio_status=fifelse(rate_b==0,'denominator_zero',fifelse(rate_a==0,'numerator_zero','positive')))]
    z[,log2_ratio:=ifelse(rate_a>0 & rate_b>0,log2(ratio),NA_real_)]
    z
  }))
  write(weekly_pairs,'weekly_pairwise_scales.csv')
  # Ein Punkt je Kreis, Phase und Typ; Typwechsel bleiben getrennt sichtbar.
  distribution <- long[,.(mean_rate=mean(value),n_weeks=.N),by=.(geo_code,geo_name,period,type,outcome)]
  distribution <- merge(distribution,phases[,.(period,phase_weeks=n_weeks)],by='period')
  distribution[,partial:=n_weeks<phase_weeks]
  write(distribution,'district_period_distribution.csv')
  ds <- distribution[,.(n_records=.N,n_districts=uniqueN(geo_code),n_partial=sum(partial),
       median=median(mean_rate),q25=quantile(mean_rate,.25),q75=quantile(mean_rate,.75),
       min=min(mean_rate),max=max(mean_rate)),by=.(period,type,outcome)]
  write(ds,'district_period_summary.csv')

  # Monatsübersicht: Mittel der Wochen, deren Montag im betreffenden Monat liegt.
  monthly <- weeks[period=='PostW5' & outcome %in% c('standard',ages)]
  monthly[,month:=as.Date(format(week_start,'%Y-%m-01'))]
  monthly <- monthly[,.(mean_weekly_rate=mean(mean),n_weeks=.N,first_week=min(week_start),last_week=max(week_start)),by=.(month,type,outcome)]
  monthly[,partial_month:=month==as.Date('2022-05-01')]
  write(monthly,'post_w5_monthly.csv')

  # Alle 21 Alterskontraste für jedes der sechs Typenpaare; zwei getrennte Ranglisten.
  rankings <- interactions[period=='All']
  rankings[,strength:=abs(estimate)]
  rankings[scale=='relative',strength:=abs(log(estimate))]
  setorderv(rankings,c('scale','strength','type_a','type_b','age_a','age_b'),c(1,-1,1,1,1,1))
  rankings[,rank:=seq_len(.N),by=scale]
  # Raten und Einzelkontraste ergänzen: große Quotienten bleiben überprüfbar.
  means <- weeks[outcome %in% ages,.(mean_rate=mean(mean)),by=.(type,outcome)]
  for(side in c('a','b')) for(age in c('a','b')) {
    col <- paste0('rate_type_',side,'_age_',age)
    idx <- match(paste(rankings[[paste0('type_',side)]],rankings[[paste0('age_',age)]]),paste(means$type,means$outcome))
    set(rankings,j=col,value=means$mean_rate[idx])
  }
  write(rankings,'age_interaction_ranking_all.csv')
  top <- rankings[rank<=5]
  write(top,'age_interaction_top5.csv')
  selected <- unique(top[,.(type_a,type_b,age_a,age_b)])
  top_phases <- merge(interactions[period!='All'],selected,by=c('type_a','type_b','age_a','age_b'))
  write(top_phases,'age_interaction_selected_periods.csv')

  # Sensitivität: jede Woche gleich gewichten, keine Inferenz mit geändertem Zielwert vermischen.
  available <- read('sensitivity_available_annual_types.csv')
  robust <- rbindlist(list(weeks[,.(type,week_start,outcome,value=mean,method='complete_mean')],
                          weeks[,.(type,week_start,outcome,value=median,method='complete_median')],
                          available[,.(type,week_start,outcome,value=mean,method='available_mean')]))
  robust <- merge(robust,unique(weeks[,.(week_start,period)]),by='week_start')
  robust <- rbindlist(list(robust,copy(robust)[,period:='All']))
  robust <- robust[,.(rate=mean(value)),by=.(period,outcome,type,method)]
  rw <- dcast(robust,period+outcome+method~type,value.var='rate')
  robust_pairs <- rbindlist(lapply(combn(1:4,2,simplify=FALSE),function(p)
    rw[,.(period,outcome,method,type_a=p[1],type_b=p[2],difference=get(as.character(p[1]))-get(as.character(p[2])),
          ratio=ifelse(get(as.character(p[2]))>0,get(as.character(p[1]))/get(as.character(p[2])),NA_real_))]))
  write(robust_pairs,'robustness_pairwise.csv')

  # Gemeinsame Gestaltung: ursprüngliche Kreistypfarben plus Linien-/Punktsymbole.
  theme_report <- theme_minimal(base_size=12,base_family='sans')+theme(
    plot.title=element_text(face='bold',size=19,color='#174B57',margin=margin(b=8)),
    plot.subtitle=element_text(size=11,color='#50616A',margin=margin(b=14)),
    plot.title.position='plot',plot.caption.position='plot',
    plot.caption=element_text(size=9,color='#52636C',hjust=0,margin=margin(t=14)),
    strip.text=element_text(face='bold',color='#214C57',size=10,hjust=0),
    strip.background=element_rect(fill='#EDF4F5',color=NA),
    panel.grid.minor=element_blank(),panel.grid.major.x=element_blank(),
    panel.grid.major.y=element_line(color='#E6ECEE',linewidth=.3),
    panel.spacing=grid::unit(1.2,'lines'),legend.position='top',legend.title=element_blank(),
    axis.text=element_text(color='#42545D'),plot.margin=margin(18,20,14,18))
  save_plot <- function(name,p,w=14,h=9) {
    ggsave(file.path(out,paste0(name,'.png')),p,width=w,height=h,dpi=220,bg='white')
    ggsave(file.path(out,paste0(name,'.pdf')),p,width=w,height=h,bg='white',
           device=function(filename,...) grDevices::quartz(file=filename,type='pdf',...))
  }
  number <- function(x) format(x,big.mark='.',decimal.mark=',',trim=TRUE,scientific=FALSE)
  annotate_pair <- function(z) {z[,pair:=factor(paste(type_a,type_b,sep=' - '),pair_ids,pair_labels)];z}
  # Absolute und relative Wochenunterschiede mit vollständiger Zeitachse, je Skala gleiche Grenzen.
  weekly_pairs <- annotate_pair(weekly_pairs)
  for(o in c('standard',ages)) {
    z <- weekly_pairs[outcome==o]
    pa <- ggplot(z,aes(week_start,difference))+geom_hline(yintercept=0,color='#89969B',linetype=2)+
      geom_line(color='#155B6C',linewidth=.65)+facet_wrap(~pair,ncol=3)+
      scale_x_date(breaks=as.Date(paste0(2020:2023,'-01-01')),date_labels='%Y',limits=as.Date(c('2019-12-30','2023-12-31')))+scale_y_continuous(labels=number)+
      labs(title='A  Absolute Differenz',x=NULL,y='Erster − zweiter Typ\nFälle je 100.000 und Woche')+theme_report
    pr <- ggplot(z,aes(week_start,log2_ratio))+geom_hline(yintercept=0,color='#89969B',linetype=2)+
      geom_line(color='#734694',linewidth=.65,na.rm=TRUE)+facet_wrap(~pair,ncol=3)+
      scale_x_date(breaks=as.Date(paste0(2020:2023,'-01-01')),date_labels='%Y',limits=as.Date(c('2019-12-30','2023-12-31')))+
      scale_y_continuous(breaks=seq(-8,8,2),labels=function(x) format(2^x,decimal.mark=',',trim=TRUE))+
      labs(title='B  Relatives Verhältnis',x=NULL,y='Erster / zweiter Typ\nlogarithmische Skala (Basis 2)')+theme_report
    title <- if(o=='standard') 'Absolute und relative Unterschiede erzählen nicht dieselbe Geschichte' else paste('Wochenunterschiede: Alter',gsub('-','–',o),'Jahre')
    save_plot(paste0('08_weekly_scales_',gsub('[+]','plus',o)),(pa/pr)+plot_annotation(title=title,
      subtitle='Vollständige Wochenzeitreihe 2020–2023 · alle sechs Typenpaare',
      caption=paste0('383 Kreise; jährliche Zuordnung. Oben Differenz, unten Verhältnis; keine doppelte y-Achse.\n',
        'Bei Nullrate eines Typs bleibt die logarithmische Kurve unterbrochen; keine Pseudocounts. Deskriptiv, ohne Wochen-CI.'),theme=theme_report),16,13)
  }
  # Standardisierte Kreisverteilungen für sämtliche festgelegten Phasen.
  for(o in c('standard',ages)) {
    z <- distribution[outcome==o]
    z[,`:=`(phase=factor(period,phases$period,phase_labels),typ=factor(type,1:4,types))]
    gm <- weeks[outcome==o,.(rate=mean(mean)),by=.(period,type)]
    gm[,`:=`(phase=factor(period,phases$period,phase_labels),typ=factor(type,1:4,types))]
    p <- ggplot(z,aes(typ,mean_rate,fill=typ))+
      geom_boxplot(width=.62,outlier.shape=NA,alpha=.8,color='#42545D',linewidth=.4)+
      geom_point(aes(shape=partial),position=position_jitter(width=.17,height=0,seed=20261123),size=.7,alpha=.38,color='#34454C')+
      geom_point(data=gm,aes(typ,rate),inherit.aes=FALSE,shape=23,fill='white',color='black',size=2.1)+
      facet_wrap(~phase,ncol=3,scales='free_y')+scale_fill_manual(values=colours,guide='none')+
      scale_shape_manual(values=c('FALSE'=16,'TRUE'=2),labels=c('Vollständige Phase','Typzugehörigkeit nur für Teilphase'))+
      scale_x_discrete(labels=short)+scale_y_continuous(labels=number,expand=expansion(mult=c(.03,.1)))+
      labs(title=if(o=='standard') 'Wie stark streuen die Kreise innerhalb der Typen?' else paste('Kreisverteilungen: Alter',gsub('-','–',o),'Jahre'),
        subtitle='Ein Punkt je Kreis und Typzugehörigkeit in der Phase · ACHTUNG: y-Skalen unterscheiden sich zwischen Phasen',
        x=NULL,y='Mittlere Wochenrate je 100.000',
        caption='Box: Median und mittlere 50 %; Punkte: Kreiswerte; weiße Raute: gleichgewichtetes Mittel der Wochen-Typmittel.\nTypwechsel: Teilphasen separat (Dreiecke), daher einzelne Kreise in zwei Gruppen. Nach W5*: KW 22/2022–52/2023.')+theme_report
    save_plot(paste0('09_distribution_',gsub('[+]','plus',o)),p,15,12)
  }
  # Vollständiges Altersprofil: keine Auswahl nach Signifikanz.
  z <- annotate_pair(contrasts[period=='All' & outcome %in% ages])
  z[,age:=factor(outcome,rev(ages),rev(age_labels))]
  atlas <- lapply(c('absolute','relative'),function(s) {
    q <- ggplot(z[scale==s],aes(estimate,age))+geom_vline(xintercept=if(s=='absolute') 0 else 1,color='#89969B',linetype=2)+
      geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15,color='#638D98')+
      geom_point(size=2,color='#155B6C')+facet_wrap(~pair,ncol=3)+theme_report+
      labs(title=if(s=='absolute') 'A  Absolute Unterschiede' else 'B  Relative Unterschiede',
           x=if(s=='absolute') 'Differenz je 100.000 und Woche' else 'Ratenverhältnis (logarithmisch)',y='Alter (Jahre)')
    if(s=='relative') q <- q+scale_x_log10(breaks=c(.85,.9,.95,1,1.05),labels=function(x) formatC(x,format='f',digits=2,decimal.mark=','))
    q
  })
  save_plot('10_age_atlas',(atlas[[1]]/atlas[[2]])+plot_annotation(title='Das vollständige Altersprofil der Stadt-Land-Unterschiede',
    subtitle='Gesamtzeitraum · sieben Altersgruppen × sechs Typenpaare',
    caption='383 Kreise; jährliche Zuordnung. Punktweise 95%-Intervalle, nicht simultan. Direkte Altersinteraktionen werden separat getestet.',theme=theme_report),16,13)
  # Top 5: erst nach vollständiger Berechnung nach Effektstärke sortieren.
  top <- annotate_pair(top)
  top[,label:=paste0(as.character(pair),'\n',gsub('-','–',age_a),' gegenüber ',gsub('-','–',age_b),' Jahren')]
  for(s in c('absolute','relative')) {
    z <- top[scale==s][order(rank)]
    z[,label:=factor(label,rev(label))]
    p <- ggplot(z,aes(estimate,label))+geom_vline(xintercept=if(s=='absolute') 0 else 1,linetype=2,color='#89969B')+
      geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.13,color='#638D98',linewidth=.8)+
      geom_point(size=3,color='#155B6C')+theme_report+
      labs(title=if(s=='absolute') 'Die fünf größten absoluten Altersinteraktionen' else 'Die fünf stärksten relativen Altersinteraktionen',
        subtitle='Explorative Auswahl aus 126 Altersinteraktionen je Skala · Gesamtzeitraum',
        x=if(s=='absolute') '(Typ A − Typ B) im ersten Alter − (Typ A − Typ B) im zweiten Alter' else '(Typ A / Typ B) im ersten Alter / (Typ A / Typ B) im zweiten Alter',y=NULL,
        caption='Sortiert nach |Differenz der Differenzen| bzw. |log(Verhältnis der Verhältnisse)|.\nPunktweise 95%-Intervalle; Auswahl kann Effekte überschätzen. Holm-p und vier Ausgangsraten stehen in der Ergebnistabelle.')
    if(s=='relative') p<-p+scale_x_log10(labels=function(x) formatC(x,format='f',digits=2,decimal.mark=','))
    save_plot(paste0('11_top5_',s),p,14,7)
  }
  # Alle 21 Altersvergleiche je Typenpaar als Dreiecksmatrizen im Anhang.
  for(s in c('absolute','relative')) {
    z<-annotate_pair(rankings[scale==s]);z[,`:=`(a=factor(age_a,ages,age_labels),b=factor(age_b,rev(ages),rev(age_labels)),
      value=if(s=='absolute') estimate else log2(estimate))]
    lim<-max(abs(z$value))
    p<-ggplot(z,aes(a,b,fill=value))+geom_tile(color='white')+
      geom_text(aes(label=if(s=='absolute') round(estimate,1) else round(estimate,3)),size=2.8)+
      facet_wrap(~pair,ncol=2)+scale_fill_gradient2(low='#977AB2',mid='#FAFAFA',high='#E9AA82',limits=c(-lim,lim),
        name=if(s=='absolute') 'Differenz der Differenzen' else 'log2 des Interaktionsverhältnisses')+
      scale_x_discrete(drop=FALSE)+scale_y_discrete(drop=FALSE)+theme_report+
      labs(title=if(s=='absolute') 'Alle absoluten Altersinteraktionen' else 'Alle relativen Altersinteraktionen',
        subtitle='Gesamtzeitraum · 21 Altersvergleiche in jedem der sechs Typenpaare',x='Erste Altersgruppe',y='Zweite Altersgruppe',
        caption='Jedes Paar einmal; leere Felder sind redundant oder Selbstvergleiche, keine fehlenden Daten.\nFarbe: Effektstärke, keine Signifikanz. Zahlen: Differenz der Differenzen bzw. untransformiertes Verhältnis.')
    save_plot(paste0('S01_all_interactions_',s),p,14,13)
  }
  # Monatliche Ansicht nach W5; unvollständigen ersten Monat sichtbar markieren.
  for(o in c('standard','ages')) {
    z<-monthly[if(o=='standard') outcome=='standard' else outcome %in% ages]
    z[,`:=`(typ=factor(type,1:4,types),age=factor(outcome,ages,age_labels))]
    p<-ggplot(z,aes(month,mean_weekly_rate,color=typ,linetype=typ))+geom_line(linewidth=.95)+
      geom_point(aes(shape=partial_month),size=1.7)+scale_shape_manual(values=c('FALSE'=16,'TRUE'=1),guide='none')+
      scale_color_manual(values=colours)+scale_linetype_manual(values=c('solid','longdash','dotdash','dotted'))+
      scale_x_date(date_breaks='3 months',date_labels='%m/%Y')+scale_y_continuous(labels=number)+theme_report+
      labs(title=if(o=='standard') 'Nach W5: Was bleibt im Monatsverlauf sichtbar?' else 'Nach W5: Monatsverlauf nach Alter',
        subtitle='Durchschnitt der Wochenraten je Monat; keine kumulierte Monatsinzidenz',x=NULL,y='Mittlere Wochenrate je 100.000',
        caption='Monatszuordnung nach Wochenmontag. Mai 2022 enthält nur den 30.05. (offener Punkt); Juni 2022–Dezember 2023 vollständig.\n383 Kreise, jährliche Typzuordnung. Rückgang der Meldungen ist nicht gleichbedeutend mit einem gleich großen Rückgang aller Infektionen.')
    if(o=='ages')p<-p+facet_wrap(~age,ncol=2)
    save_plot(paste0('12_post_w5_',o),p,14,if(o=='standard') 7 else 12)
  }
  r<-annotate_pair(robust_pairs[period=='All' & outcome=='standard'])
  r[,`:=`(pair=factor(as.character(pair),rev(pair_labels)),method=factor(method,c('complete_mean','complete_median','available_mean'),
    c('383 Kreise: Wochenmittel','383 Kreise: Wochenmedian','Verfügbare Kreise: Wochenmittel')))]
  p<-ggplot(r,aes(difference,pair,color=method,shape=method))+geom_vline(xintercept=0,linetype=2,color='#89969B')+
    geom_point(size=3,position=position_dodge(width=.5))+scale_color_manual(values=c('#155B6C','#9B644B','#708F43'))+theme_report+
    labs(title='Wie empfindlich sind die Ergebnisse gegenüber der Zusammenfassung?',subtitle='Altersstandardisierte Raten · Gesamtzeitraum · drei deskriptive Auswertungen',
      x='Erster − zweiter Typ: mittlere wöchentliche Differenz je 100.000',y=NULL,
      caption='Wochenmediane werden über die Zeit gemittelt; das ist kein Median aller Kreiswochen.\nVerfügbare Kreise: je Woche gültige standardisierte Raten (alle sieben Altersgruppen erforderlich). Keine zusätzlichen Tests.')
  save_plot('13_robustness',p,14,7)

  # Vertiefung des in beiden Ranglisten führenden Kontrasts; Auswahl ausdrücklich explorativ.
  leader <- top[scale=='absolute' & rank==1]
  z <- top_phases[type_a==leader$type_a & type_b==leader$type_b & age_a==leader$age_a & age_b==leader$age_b]
  z[,phase:=factor(period,rev(phases$period),rev(phase_labels))]
  detail <- lapply(c('absolute','relative'),function(s) {
    q <- ggplot(z[scale==s],aes(estimate,phase))+
      geom_vline(xintercept=if(s=='absolute') 0 else 1,linetype=2,color='#89969B')+
      geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15,color='#638D98',na.rm=TRUE)+
      geom_point(color='#155B6C',size=2.5,na.rm=TRUE)+theme_report+
      scale_y_discrete(drop=FALSE)+labs(title=if(s=='absolute') 'A  Absolute Altersinteraktion' else 'B  Relative Altersinteraktion',
        x=if(s=='absolute') 'Differenz der Differenzen je 100.000' else 'Verhältnis der Ratenverhältnisse',y=NULL)
    if(s=='relative')q<-q+scale_x_log10(labels=function(x) formatC(x,format='f',digits=2,decimal.mark=','))
    q
  })
  save_plot('14_leading_interaction_periods',(detail[[1]]|detail[[2]])+plot_annotation(
    title='Wann entsteht die stärkste Altersinteraktion?',
    subtitle=paste0(as.character(leader$pair),' · ',leader$age_a,' gegenüber ',leader$age_b,' Jahren'),
    caption='Nach Gesamtrangliste ausgewähltes Beispiel; explorativ. Punktweise 95%-Intervalle, Holm-Tests separat.\nVor W1: relatives Verhältnis wegen Nullraten nicht schätzbar. Nach W5*: KW 22/2022–52/2023.',theme=theme_report),14,8)
  # Inhaltliche Prüfungen der neuen Ableitungen.
  stopifnot(nrow(rankings)==252L,all(rankings[, .N,by=.(type_a,type_b,scale)]$N==21L),
    all(top[, .N,by=scale]$N==5L), nrow(weekly_pairs)==209L*8L*6L)
  check <- merge(weekly_pairs[outcome=='standard',.(estimate_check=mean(difference)),by=.(type_a,type_b)],
                 contrasts[period=='All' & outcome=='standard' & scale=='absolute'],by=c('type_a','type_b'))
  stopifnot(max(abs(check$estimate_check-check$estimate))<1e-8)
  z<-rankings[scale=='absolute'];expected<-(z$rate_type_a_age_a-z$rate_type_b_age_a)-(z$rate_type_a_age_b-z$rate_type_b_age_b)
  stopifnot(max(abs(z$estimate-expected))<1e-8)
  z<-rankings[scale=='relative'];expected<-(z$rate_type_a_age_a/z$rate_type_b_age_a)/(z$rate_type_a_age_b/z$rate_type_b_age_b)
  stopifnot(max(abs(z$estimate-expected))<1e-8)
  check<-monthly[,.(value=sum(mean_weekly_rate*n_weeks)/sum(n_weeks)),by=.(type,outcome)]
  check<-merge(check,weeks[period=='PostW5' & outcome %in% c('standard',ages),.(ref=mean(mean)),by=.(type,outcome)],by=c('type','outcome'))
  stopifnot(max(abs(check$value-check$ref))<1e-8,all(monthly[partial_month==TRUE,n_weeks]==1L))
  # Kreiswochen bleiben auch bei Typwechseln genau einmal enthalten.
  stopifnot(sum(distribution$n_weeks)==nrow(long),all(distribution$n_weeks<=distribution$phase_weeks))
  writeLines(c('BESTANDEN: alle Altersvergleiche, Ausgangsraten, Wochenkontraste, Monatsgewichtung und Typwechsel.',
               paste('Erstellt:',Sys.time())),file.path(out,'EXTENDED_VALIDATION.txt'))
  message('ERWEITERTE ANALYSE UND PRÜFUNGEN ABGESCHLOSSEN')
})
