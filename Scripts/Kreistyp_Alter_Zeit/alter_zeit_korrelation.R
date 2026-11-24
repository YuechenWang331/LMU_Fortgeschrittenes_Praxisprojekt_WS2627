# Erläuternde Tabellen, Altersgrafiken und deskriptive Zeitreihenkorrelationen.
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(patchwork)})
local({
out<-'results/Kreistyp_Alter_Zeit';read<-function(f)fread(file.path(out,f));write<-function(z,f)fwrite(z,file.path(out,f))
ages<-c('0-5','6-17','18-39','40-59','60-69','70-79','80+')
types<-c('Großstadt','Städtisch','Ländlich verdichtet','Ländlich dünn')
pairs<-combn(1:4,2,simplify=FALSE);pn<-c('Großstadt\n− städtisch','Großstadt\n− verdichtet','Großstadt\n− dünn','Städtisch\n− verdichtet','Städtisch\n− dünn','Verdichtet\n− dünn')
phases<-read('period_definitions.csv');weeks<-read('weekly_district_rates.csv');con<-read('pairwise_contrasts.csv')
x<-as.data.table(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
x[,age_group:=as.character(age_group)]
missing<-fread(file.path(out,'audit_missing_denominators.csv'),colClasses=c(geo_code='character'))
d<-x[!geo_code %in% missing$geo_code];stopifnot(uniqueN(d$geo_code)==383)
ref<-read('standard_population_2021.csv')[,.(age_group,population_400=population,weight_400=weight)]
pop383<-unique(d[iso_year==2021,.(geo_code,age_group,population)])[,.(population_383=sum(population)),by=age_group]
ref<-merge(ref,pop383,by='age_group');ref[,weight_383:=population_383/sum(population_383)];ref<-ref[match(ages,age_group)]
stopifnot(abs(sum(ref$weight_383)-1)<1e-12,abs(sum(ref$weight_400)-1)<1e-12)
write(ref,'reference_400_383.csv')
z<-merge(d,ref,by='age_group')
std<-z[,.(ref400=sum(incidence*weight_400),ref383=sum(incidence*weight_383)),by=.(geo_code,week_start,type=kreistyp_code)]
wm<-std[,.(ref400=mean(ref400),ref383=mean(ref383)),by=.(type,week_start)]
means<-wm[,.(ref400=mean(ref400),ref383=mean(ref383)),by=type]
rs<-rbindlist(lapply(pairs,function(p)data.table(type_a=p[1],type_b=p[2],difference_400=means[type==p[1],ref400]-means[type==p[2],ref400],difference_383=means[type==p[1],ref383]-means[type==p[2],ref383])))
rs[,change:=difference_383-difference_400];write(rs,'reference_sensitivity.csv')
ex<-z[geo_code=='09162' & week_start==as.Date('2022-03-07')];ex[,`:=`(actual_share=population/sum(population),contribution=incidence*weight_400)]
ex<-ex[match(ages,age_group)];write(ex[,.(geo_code,geo_name,week_start,age_group,cases,population,incidence,actual_share,weight_400,contribution)],'standardisation_example.csv')
stopifnot(abs(sum(ex$contribution)-std[geo_code=='09162' & week_start==as.Date('2022-03-07'),ref400])<1e-8)
av<-read('sensitivity_available_annual_types.csv')
write(av[outcome=='standard',.(n_available=sum(n)),by=week_start],'available_sample_by_week.csv')
# Alle Phasen und alle Wochen statt ausgewählter Spitzenwochen.
wp<-read('weekly_pairwise_scales.csv')
ps<-wp[,.(n_weeks=.N,mean_difference=mean(difference),mean_rate_a=mean(rate_a),mean_rate_b=mean(rate_b),share_a_lower=mean(difference<0),share_equal=mean(difference==0),share_a_higher=mean(difference>0)),by=.(period,outcome,type_a,type_b)]
ps[,ratio_of_means:=fifelse(mean_rate_b>0,mean_rate_a/mean_rate_b,NA_real_)]
write(ps,'period_difference_overview.csv')
base<-theme_minimal(base_size=12)+theme(plot.title=element_text(face='bold',color='#174B57',size=18),plot.subtitle=element_text(color='#52636C'),panel.grid.minor=element_blank(),legend.position='top',strip.text=element_text(face='bold',color='#174B57'),plot.caption=element_text(hjust=0,color='#52636C',size=9),plot.margin=margin(15,20,15,15))
save<-function(name,g,w=13,h=7){for(ext in c('png','pdf'))ggsave(file.path(out,paste0(name,'.',ext)),g,width=w,height=h,dpi=220,bg='white',device=if(ext=='pdf')function(filename,...)grDevices::quartz(file=filename,type='pdf',...) else 'png')}
fmt<-function(v,d=2)formatC(v,format='f',digits=d,decimal.mark=',')
# Kompakte Übersicht: alle Alter und Typenpaare; Farbe zeigt Größe, nicht Signifikanz.
a<-con[period=='All' & outcome %in% ages];a[,pair:=factor(paste(type_a,type_b),sapply(pairs,paste,collapse=' '),pn)];a[,age:=factor(outcome,rev(ages))]
plots<-lapply(c('absolute','relative'),function(s){q<-a[scale==s];q[,value:=if(s=='absolute')estimate else log(estimate)];lim<-max(abs(q$value));ggplot(q,aes(pair,age,fill=value))+geom_tile(color='white',linewidth=1.4)+geom_text(aes(label=fmt(estimate,if(s=='absolute')1 else 3)),size=3.7)+scale_fill_gradient2(low='#B4D7DE',mid='#FFFFFF',high='#F4C6AE',limits=c(-lim,lim),guide='none')+base+theme(panel.grid=element_blank(),axis.text.x=element_text(size=9))+labs(title=if(s=='absolute')'A · Absolute Differenz (A − B)' else 'B · Ratenverhältnis (A / B)',x=NULL,y='Alter (Jahre)')})
save('17_age_profile_clear',plots[[1]]/plots[[2]]+plot_annotation(title='Wie verändert sich der Stadt-Land-Abstand mit dem Alter?',subtitle='Alle sieben Altersgruppen und sechs Typenpaare · 2020–2023',caption='Blau: erster Typ niedriger; orange: erster Typ höher. Neutralwert oben 0, unten 1.\nZahlen sind Effektgrößen, keine Signifikanzzeichen. Punktweise Intervalle stehen in der ergänzenden Altersgrafik.',theme=base),14,10)
raw<-weeks[outcome %in% ages,.(rate=mean(mean)),by=.(type,outcome)]
foc<-dcast(raw[type %in% c(1,4)],outcome~type,value.var='rate')[match(ages,outcome)];foc[,`:=`(difference=`1`-`4`,ratio=`1`/`4`,age=factor(outcome,rev(ages)))]
left<-ggplot(foc,aes(y=age))+geom_segment(aes(x=`1`,xend=`4`,yend=age),color='#BCCACD',linewidth=1.2)+geom_point(aes(x=`1`,color='Großstadt'),size=3.5)+geom_point(aes(x=`4`,color='Ländlich dünn'),shape=17,size=3.5)+scale_color_manual(values=c('Großstadt'='#D0582B','Ländlich dünn'='#69AD55'))+base+labs(title='A · Zwei Ausgangsraten',x='Mittlere Wochenrate je 100.000',y='Alter',color=NULL)
right<-ggplot(foc,aes(difference,age))+geom_vline(xintercept=0,linetype=2,color='grey60')+geom_segment(aes(x=0,xend=difference,yend=age),color='#A9CCD2',linewidth=1.3)+geom_point(size=3,color='#087F8C')+geom_text(aes(label=fmt(difference)),hjust=1.15,size=3.6)+scale_x_continuous(expand=expansion(mult=c(.25,.08)))+base+labs(title='B · Daraus entsteht der Abstand',x='Großstadt − ländlich dünn',y=NULL)
save('18_age_interaction_explained',left+right+plot_annotation(title='Altersinteraktion bedeutet: Zwei Stadt-Land-Abstände vergleichen',subtitle='Alle Altersgruppen bleiben sichtbar · Beispiel: 18–39 gegenüber 70–79 Jahren',caption='18–39: −36,71; 70–79: −3,86. Absolute Interaktion aus ungerundeten Zahlen: −32,84.\nRelativ: 0,879 / 0,966 = 0,910. Die Ratenverhältnisse unterscheiden sich; das ist kein Unterschied der Altersanteile.',theme=base),14,7)
# Zusammenhang der Zeitreihen: Niveau, erste Differenzen, Rangkorrelation und Phasen.
series<-dcast(weeks[outcome %in% c('standard',ages)],week_start+period~type+outcome,value.var='mean');setorder(series,week_start)
sets<-list(kreistyp=paste0(1:4,'_standard'))
for(t in 1:4)sets[[paste0('alter_typ',t)]]<-paste0(t,'_',ages)
safe_cor<-function(a,b,method='pearson') { if(length(a)<3 || sd(a)==0 || sd(b)==0) return(NA_real_); cor(a,b,method=method) }
rows<-list();ac<-list();B<-1999L;set.seed(20261124)
for(group in names(sets)) {
 cols<-sets[[group]];Y<-as.matrix(series[,..cols]);D<-apply(Y,2,diff)
 for(mode in c('Niveau','Wochenänderung')) {
  mat<-if(mode=='Niveau')Y else D;dates<-if(mode=='Niveau')series$week_start else series$week_start[-1];phase<-if(mode=='Niveau')series$period else ifelse(series$period[-1]==series$period[-nrow(series)],series$period[-1],NA_character_)
  for(p in c('All',phases$period)) {use<-if(p=='All')seq_len(nrow(mat)) else which(phase==p);if(length(use)<4)next
   for(ij in combn(seq_along(cols),2,simplify=FALSE)) rows[[length(rows)+1]]<-data.table(group=group,mode=mode,period=p,series_a=cols[ij[1]],series_b=cols[ij[2]],n=length(use),pearson=safe_cor(mat[use,ij[1]],mat[use,ij[2]]),spearman=safe_cor(mat[use,ij[1]],mat[use,ij[2]],method='spearman'))
  }
  for(j in seq_along(cols)){aa<-as.numeric(acf(mat[,j],plot=FALSE,lag.max=12)$acf)[-1];ac[[length(ac)+1]]<-data.table(group=group,series=cols[j],mode=mode,lag=1:12,acf=aa)}
 }
}
corr<-rbindlist(rows);corr[,status:=ifelse(is.finite(pearson),'ok','constant_series')];write(corr,'time_series_correlations.csv');acf_values<-rbindlist(ac);write(acf_values,'time_series_acf.csv')
# Explorative Blockintervalle nur für Änderungen; keine i.i.d.-p-Werte.
ci<-list()
for(group in names(sets)) {
 cols<-sets[[group]];D<-apply(as.matrix(series[,..cols]),2,diff);ij<-combn(seq_along(cols),2);n<-nrow(D)
 for(L in c(4L,8L,12L)) {
  reps<-replicate(B,{starts<-sample.int(n-L+1,ceiling(n/L),replace=TRUE);ind<-unlist(lapply(starts,function(s)s:(s+L-1)))[seq_len(n)];C<-cor(D[ind,,drop=FALSE]);C[t(ij)]})
  for(k in seq_len(ncol(ij)))ci[[length(ci)+1]]<-data.table(group=group,series_a=cols[ij[1,k]],series_b=cols[ij[2,k]],block_weeks=L,n_reps=B,estimate=cor(D)[ij[1,k],ij[2,k]],lower=quantile(reps[k,],.025,na.rm=TRUE),upper=quantile(reps[k,],.975,na.rm=TRUE))
 }
}
write(rbindlist(ci),'time_series_block_intervals.csv')
# Korrelation ist nicht Differenz: gepaarte Balken für Niveau und Änderung.
z<-corr[group=='kreistyp' & period=='All'];z[,pair:=factor(paste(substr(series_a,1,1),substr(series_b,1,1)),sapply(pairs,paste,collapse=' '),gsub('\n',' ',pn))]
g<-ggplot(z,aes(pearson,pair,color=mode,shape=mode))+geom_point(size=3,position=position_dodge(width=.45))+scale_x_continuous(limits=c(-1,1),breaks=seq(-1,1,.25),labels=function(x)fmt(x,2))+scale_color_manual(values=c('Niveau'='#9C9FA2','Wochenänderung'='#087F8C'))+geom_vline(xintercept=0,color='grey70')+base+labs(title='Verlaufen die vier Kreistypen zeitlich gemeinsam?',subtitle='Pearson-Korrelation: ursprüngliche Wochenraten und Veränderungen zur Vorwoche',x='Zeitliche Korrelation r',y=NULL,color=NULL,shape=NULL,caption='Standardisierte Typmittel; 209 Wochen bzw. 208 Änderungen. Hohe Korrelation bedeutet nicht gleiche Höhe.\nKeine gewöhnlichen Korrelations-p-Werte: Wochen sind abhängig und die Dynamik verändert sich über die Zeit.')
save('19_type_time_correlation',g,13,6.5)
z<-corr[group!='kreistyp' & period=='All'];z[,`:=`(age_a=factor(sub('^[0-9]_','',series_a),ages),age_b=factor(sub('^[0-9]_','',series_b),rev(ages)),typ=factor(sub('alter_typ','',group),1:4,types))]
for(mode0 in c('Niveau','Wochenänderung')) {
 g<-ggplot(z[mode==mode0],aes(age_a,age_b,fill=pearson))+geom_tile(color='white',linewidth=.7)+geom_text(aes(label=fmt(pearson)),size=3.3)+facet_wrap(~typ,ncol=2)+scale_fill_gradient2(low='#D99076',mid='#FFFFFF',high='#4D9BA6',limits=c(-1,1),name='r')+base+theme(panel.grid=element_blank())+labs(title=paste('Altersgruppen im Zeitvergleich:',mode0),subtitle='Alle 21 Altersgruppenpaare innerhalb jedes Kreistyps',x='Erste Altersgruppe',y='Zweite Altersgruppe',caption='Zeitliche Pearson-Korrelation, keine Altersinteraktion und kein Kausalnachweis. Leere Felder sind redundante Vergleiche.\nDie Phasenwerte und Spearman-Korrelationen stehen in der Tabelle; keine i.i.d.-Signifikanztests.')
 save(if(mode0=='Niveau')'20_age_time_correlation_levels' else '20_age_time_correlation_changes',g,13,10)
}
g<-ggplot(acf_values[group=='kreistyp'],aes(lag,acf,color=mode))+geom_hline(yintercept=0,color='grey70')+geom_line()+geom_point(size=1.6)+facet_wrap(~factor(series,paste0(1:4,'_standard'),types),ncol=2)+scale_color_manual(values=c('Niveau'='#9C9FA2','Wochenänderung'='#087F8C'))+base+labs(title='Benachbarte Wochen sind nicht unabhängig',subtitle='Autokorrelation der standardisierten Typmittel und ihrer ersten Differenzen',x='Abstand in Wochen',y='Autokorrelation',color=NULL,caption='Differenzierung garantiert keine Unabhängigkeit oder Stationarität. Keine weißen-Rauschens-Konfidenzbänder eingezeichnet.')
save('21_time_autocorrelation',g,12,8)
stopifnot(nrow(corr[period=='All'])==180,nrow(rbindlist(ci))==270,all(is.finite(corr[period=='All',pearson])))
writeLines(c('PRÜFUNGEN BESTANDEN','383-Kreise-Referenzgewichte summieren sich zu 1.','Reales Standardisierungsbeispiel reproduziert Kreisrate.','6 Typenpaare und 4 × 21 Alterspaare auf Niveau- und Änderungsskala.','Phasendifferenzen überschreiten keine Phasengrenze.','Blockintervalle 4/8/12 Wochen, je 1.999 gemeinsame Ziehungen.'),file.path(out,'TIME_SERIES_VALIDATION.txt'))
})
