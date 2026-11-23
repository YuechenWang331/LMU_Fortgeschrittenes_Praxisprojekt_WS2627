# Räumliche Sensitivität und ergänzende Panelmodelle; keine kausale Interpretation.
# Aufruf aus dem Projektstamm: source('Scripts/Kreistyp_Alter_Zeit/modell_raum_zeit.R')
if (dir.exists('.R-library')) .libPaths(c(normalizePath('.R-library'), .libPaths()))
suppressPackageStartupMessages({library(data.table); library(fixest); library(sf); library(ggplot2); library(patchwork)})
setFixest_nthreads(2)
out <- 'results/Kreistyp_Alter_Zeit'
x <- as.data.table(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
x[, age_group := as.character(age_group)]
excluded <- fread(file.path(out,'audit_missing_denominators.csv'),colClasses=c(geo_code='character'))$geo_code
x <- x[!geo_code %in% excluded]
stopifnot(uniqueN(x$geo_code)==383L)
periods <- fread(file.path(out,'period_definitions.csv'))
for(j in seq_len(nrow(periods))) x[week_start >= periods$start[j] & week_start <= periods$end[j],period:=periods$period[j]]
x[, type:=as.integer(kreistyp_code)]
ids <- sort(unique(x$geo_code))
geo <- st_read('data_geo/landkreise_simplify200.geojson',quiet=TRUE)
geo <- st_transform(geo,3035)
# Schwerpunkt im europäischen flächentreuen Koordinatensystem; Raster vor der Auswertung festgelegt.
centres <- suppressWarnings(st_centroid(geo))
xy <- st_coordinates(centres)
coords <- data.table(geo_code=as.character(geo$AGS),east=xy[,1],north=xy[,2])
coords <- coords[match(ids,geo_code)]
stopifnot(!anyNA(coords),!anyDuplicated(coords$geo_code))
coords[, kreis:=geo_code]
coords[, block100:=paste(floor(east/1e5),floor(north/1e5),sep='_')]
coords[, block200:=paste(floor(east/2e5),floor(north/2e5),sep='_')]
coords[, block100_shift:=paste(floor((east+5e4)/1e5),floor((north+5e4)/1e5),sep='_')]
fwrite(coords,file.path(out,'spatial_blocks.csv'))
blocks <- c('kreis','block100','block200','block100_shift')
fwrite(rbindlist(lapply(blocks,function(b) coords[,.(schema=b,n_blocks=uniqueN(get(b)),min_kreise=min(table(get(b))),max_kreise=max(table(get(b))))])),file.path(out,'spatial_block_audit.csv'))
# Gleiche Kreisgewichte: OLS auf Raten; PPML auf Raten als Quasi-Likelihood (keine Pseudocounts).
d <- merge(x[age_group %in% c('18-39','70-79')],coords,by='geo_code')
d[, jung:=as.integer(age_group=='18-39')]
d[, kreis_alter:=paste(geo_code,age_group)]
d[, woche_alter:=paste(week_start,age_group)]
terms <- character()
for(a in c('j','a')) for(t in 2:4) {
  flag <- as.integer(d$jung==as.integer(a=='j') & d$type==t)
  nm <- paste0('basis_',a,t); d[,(nm):=flag]; terms<-c(terms,nm)
  for(p in setdiff(periods$period,'W4')) {
    nm <- paste0('phase_',a,t,'_',p); d[,(nm):=flag*as.integer(period==p)]; terms<-c(terms,nm)
  }
}
fml <- as.formula(paste('incidence ~',paste(terms,collapse='+'),'| kreis_alter + woche_alter'))
message('Schätze absolutes Panelmodell …')
m_abs <- feols(fml,d,data.save=TRUE,fixef.tol=1e-9)
message('Schätze relatives PPML-Panelmodell …')
# P0 enthält strukturell leere Typ-Alters-Zellen: kein endlicher relativer Kontrast.
zero_audit <- d[,.(faelle=sum(cases)),by=.(period,type,age_group)]
fwrite(zero_audit,file.path(out,'panel_zero_cells.csv'))
stopifnot(all(zero_audit[period!='P0',faelle]>0))
d_rel <- d[period!='P0']
terms_rel <- terms[!grepl('_P0$',terms)]
fml_rel <- as.formula(paste('incidence ~',paste(terms_rel,collapse='+'),'| kreis_alter + woche_alter'))
m_rel <- fepois(fml_rel,d_rel,data.save=TRUE,glm.iter=200,fixef.tol=1e-9,glm.tol=1e-9)
stopifnot(isTRUE(m_rel$convStatus),all(is.finite(coef(m_abs))),all(is.finite(coef(m_rel))))
models <- list(absolute=m_abs,relative=m_rel)
rows<-list(); z<-0L
for(s in names(models)) {
  m<-models[[s]]
  for(b in blocks) {
    V<-vcov(m,cluster=as.formula(paste0('~',b)),ssc=ssc(K.adj=TRUE,G.adj=TRUE,t.df='min'))
    G<-uniqueN(d[[b]]); crit<-qt(.975,G-1)
    for(p in setdiff(periods$period,if(s=='relative')c('W4','P0') else 'W4')) for(pair in combn(1:4,2,simplify=FALSE)) {
      L<-setNames(numeric(length(coef(m))),names(coef(m)))
      for(a in c('j','a')) for(k in 1:2) if(pair[k]!=1) {
        nm<-paste0('phase_',a,pair[k],'_',p)
        stopifnot(nm %in% names(L))
        L[nm]<-L[nm]+ifelse(a=='j',1,-1)*ifelse(k==1,1,-1)
      }
      theta<-sum(L*coef(m)); se<-sqrt(drop(t(L)%*%V%*%L))
      trans<-if(s=='relative') exp else identity
      z<-z+1L;rows[[z]]<-data.table(scale=s,schema=b,period=p,reference='W4',type_a=pair[1],type_b=pair[2],
        estimate=trans(theta),lower=trans(theta-crit*se),upper=trans(theta+crit*se),se=se,p=2*pt(-abs(theta/se),G-1),n_blocks=G,n_obs=nobs(m))
    }
  }
}
model_results<-rbindlist(rows)
model_results[,p_holm:=p.adjust(p,'holm'),by=schema]
fwrite(model_results,file.path(out,'panel_age_interaction_changes.csv'))
fwrite(rbindlist(lapply(names(models),function(s) data.table(scale=s,n_obs=nobs(models[[s]]),n_input=if(s=='relative')nrow(d_rel) else nrow(d),
  n_coef=length(coef(models[[s]])),removed_terms=paste(models[[s]]$collin.var,collapse=';'),
  converged=if(s=='relative')models[[s]]$convStatus else TRUE))),file.path(out,'panel_model_diagnostics.csv'))
# Große Modellobjekte bleiben lokal; Koeffizienten und Diagnostik sind portable Tabellen.
saveRDS(models,file.path(out,'panel_models.rds'))
fwrite(rbindlist(lapply(names(models),function(s)data.table(scale=s,term=names(coef(models[[s]])),estimate=unname(coef(models[[s]]))))),file.path(out,'panel_coefficients.csv'))
stopifnot(nrow(model_results)==360L)
# PPML-Gleichungen: vorhergesagte und beobachtete Summen je Fixeffekt müssen übereinstimmen.
check_rel<-copy(d_rel)
check_rel[,fehler:=incidence-fitted(m_rel)]
score_error<-max(sapply(c('kreis_alter','woche_alter'),function(v)check_rel[,.(err=abs(sum(fehler))/(1+sum(incidence))),by=v][,max(err)]))
stopifnot(score_error<1e-6)
fwrite(data.table(pruefung='PPML_Fixeffekt_Gleichungen',max_rel_fehler=score_error),file.path(out,'panel_score_check.csv'))
# Unabhängige Prüfung der OLS-Koeffizienten mit Frisch-Waugh-Lovell und QR-Zerlegung.
X<-as.matrix(d[,..terms]); Y<-cbind(d$incidence,X)
Y<-demean(Y,f=list(d$kreis_alter,d$woche_alter),tol=1e-10)
check<-lm.fit(Y[,-1,drop=FALSE],Y[,1]); names(check$coefficients)<-terms
use<-names(coef(m_abs)); stopifnot(max(abs(check$coefficients[use]-coef(m_abs)))<1e-5)
rm(Y,X,check)
# Räumliche Unsicherheit für die bisherigen Gruppenmittel: Einflussbeiträge je vollständigem Kreis.
weights<-fread(file.path(out,'standard_population_2021.csv'))[,.(age_group,weight)]
y<-merge(x,weights,by='age_group')
standard<-y[,.(value=sum(weight*incidence)),by=.(geo_code,type,week_start,period)]
long<-rbind(y[,.(geo_code,type,week_start,period,outcome=age_group,value=incidence)],standard[,outcome:='standard'],use.names=TRUE)
weekly<-long[,.(mu=mean(value),n=.N),by=.(type,week_start,outcome)]
long<-merge(long,weekly,by=c('type','week_start','outcome'))
long[,score:=(value-mu)/n]
P<-c('All',periods$period); A<-c('0-5','6-17','18-39','40-59','60-69','70-79','80+','standard')
M<-array(0,c(4,length(A),length(P)),dimnames=list(1:4,A,P))
I<-array(0,c(length(ids),4,length(A),length(P)),dimnames=list(ids,1:4,A,P))
for(p in P) {
  part<-if(p=='All') long else long[period==p]
  nw<-uniqueN(part$week_start)
  avg<-unique(part[,.(type,outcome,week_start,mu)])[,.(value=mean(mu)),by=.(type,outcome)]
  for(k in seq_len(nrow(avg))) M[as.character(avg$type[k]),avg$outcome[k],p]<-avg$value[k]
  ss<-part[,.(s=sum(score)/nw),by=.(geo_code,type,outcome)]
  for(k in seq_len(nrow(ss))) I[ss$geo_code[k],as.character(ss$type[k]),ss$outcome[k],p]<-ss$s[k]
}
# Delta-Methode: Differenzen linear, Verhältnisse auf Log-Skala; räumliche Block-Sandwich-Varianz.
rows<-list();z<-0L
for(p in P) for(pair in combn(1:4,2,simplify=FALSE)) for(ages in c(list('standard'),combn(A[1:7],2,simplify=FALSE))) for(s in c('absolute','relative')) {
  theta<-0; influence<-rep(0,length(ids)); valid<-TRUE
  for(aa in seq_along(ages)) for(tt in 1:2) {
    v<-M[as.character(pair[tt]),ages[aa],p]
    sign<-ifelse(aa==1,1,-1)*ifelse(tt==1,1,-1)
    if(s=='relative' && v<=0) {valid<-FALSE;next}
    theta<-theta+sign*if(s=='absolute')v else log(v)
    influence<-influence+sign*I[,as.character(pair[tt]),ages[aa],p]/if(s=='absolute')1 else v
  }
  for(b in blocks) {
    G<-uniqueN(coords[[b]]);u<-rowsum(influence,coords[[b]],reorder=FALSE)
    se<-sqrt(sum(u^2)*G/(G-1));crit<-qt(.975,G-1);trans<-if(s=='relative')exp else identity
    z<-z+1L;rows[[z]]<-data.table(period=p,type_a=pair[1],type_b=pair[2],age_a=ages[1],age_b=if(length(ages)==2)ages[2] else NA_character_,scale=s,schema=b,
      estimate=if(valid)trans(theta) else NA_real_,lower=if(valid)trans(theta-crit*se) else NA_real_,upper=if(valid)trans(theta+crit*se) else NA_real_,
      p=if(valid && se>0)2*pt(-abs(theta/se),G-1) else NA_real_,se=if(valid)se else NA_real_,n_blocks=G)
  }
}
spatial<-rbindlist(rows)
spatial[,family:=paste(ifelse(period=='All','gesamt','phasen'),ifelse(age_a=='standard','standard','alter'),sep='_')]
spatial[,p_holm:=p.adjust(p,'holm'),by=.(schema,family)]
fwrite(spatial,file.path(out,'spatial_contrasts.csv'))
# Punktschätzer müssen die bestehenden Ergebnisse exakt reproduzieren.
old<-fread(file.path(out,'age_interactions.csv'))
compare<-merge(spatial[schema=='block100' & age_a!='standard'],old,by=c('period','type_a','type_b','age_a','age_b','scale'),suffixes=c('_neu','_alt'))
stopifnot(max(abs(compare$estimate_neu-compare$estimate_alt),na.rm=TRUE)<1e-7,nrow(compare)==2520)
sys.source('Scripts/Kreistyp_Alter_Zeit/modell_abbildungen.R',envir=environment())
writeLines(c('PRÜFUNGEN BESTANDEN',paste('Kreise:',length(ids)),paste('OLS/PPML-Beobachtungen:',nobs(m_abs),nobs(m_rel)),
  'OLS mit unabhängiger FWL/QR-Rechnung geprüft.', '2.520 räumliche Punktschätzer reproduzieren die bestehende Altersanalyse.',
  'Absolut: acht Phasen gegenüber W4; relativ: sieben Phasen, P0 wegen Nullzellen ausgeschlossen. Je sechs Typenpaare.',paste('fixest:',packageVersion('fixest'))),file.path(out,'MODEL_VALIDATION.txt'))
capture.output(sessionInfo(),file=file.path(out,'model_session_info.txt'))
message('Räumliche Sensitivität und Panelmodelle vollständig gespeichert.')
