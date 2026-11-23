# Run from the project root, preferably in an isolated environment:
# covid_age_time <- new.env(); sys.source('Scripts/Kreistyp_Alter_Zeit/run_analysis.R', covid_age_time)
# District-weighted descriptive inference. Does not modify source data or global objects.
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(ggplot2))
run_analysis <- function(B = 1999L, seed = 20261123L) {
  out <- 'results/Kreistyp_Alter_Zeit'
  dir.create(out, recursive = TRUE, showWarnings = FALSE)
  input <- 'data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'
  x <- as.data.table(readRDS(input))
  ages <- levels(x$age_group)
  x[, age_group := as.character(age_group)]
  stopifnot(nrow(x) == 400L * 209L * 7L,
            !anyDuplicated(x[, .(geo_code, week_start, age_group)]),
            all(is.finite(x$cases)), all(x$cases >= 0))
  valid <- is.finite(x$incidence) & is.finite(x$population) & x$population > 0
  stopifnot(max(abs(x$incidence[valid] - x$cases[valid]/x$population[valid]*1e5)) < 1e-7)
  missing <- unique(x[!valid, .(geo_code, geo_name, iso_year, age_group, population_status)])
  fwrite(missing, file.path(out, 'audit_missing_denominators.csv'))
  types <- unique(x[, .(geo_code, iso_year, kreistyp_code, kreistyp_name)])
  changed <- types[, .(n_types = uniqueN(kreistyp_code)), by = geo_code][n_types > 1]$geo_code
  fwrite(types[geo_code %in% changed], file.path(out, 'audit_type_changes.csv'))
  fixed <- types[iso_year == 2023, .(geo_code, type = kreistyp_code)]
  x <- merge(x, fixed, by = 'geo_code')
  keep <- setdiff(unique(x$geo_code), missing$geo_code)
  d <- x[geo_code %in% keep]
  stopifnot(length(keep) == 383L, all(is.finite(d$incidence)))
  fwrite(unique(x[, .(geo_code, geo_name, type)])[, included := geo_code %in% keep],
         file.path(out, 'audit_district_sample.csv'))
  # 2021 has complete seven-band denominators for all 400 districts.
  pop <- unique(x[, .(geo_code, type, iso_year, age_group, population)])
  reference <- pop[iso_year == 2021, .(population = sum(population)), by = age_group]
  reference[, weight := population / sum(population)]
  equal_weights <- pop[iso_year == 2021,
    .(age_group, share = population / sum(population)), by = geo_code][,
    .(weight_equal_district = mean(share)), by = age_group]
  reference <- merge(reference, equal_weights, by = 'age_group')
  setorder(reference, age_group)
  stopifnot(abs(sum(reference$weight)-1)<1e-12, abs(sum(reference$weight_equal_district)-1)<1e-12)
  fwrite(reference, file.path(out, 'standard_population_2021.csv'))
  # Mutually exclusive periods covering every observed week, including gaps.
  periods <- data.table(period = c('P0','W1','G1','W2','W3','G2','W4','W5','PostW5'),
    start = as.Date(c('2019-12-30','2020-03-02','2020-05-18','2020-09-28','2021-03-01',
                     '2021-06-14','2021-08-02','2021-12-27','2022-05-30')),
    end = as.Date(c('2020-03-01','2020-05-17','2020-09-27','2021-02-28','2021-06-13',
                   '2021-08-01','2021-12-26','2022-05-29','2023-12-31')))
  for (j in seq_len(nrow(periods))) {
    x[week_start >= periods$start[j] & week_start <= periods$end[j], period := periods$period[j]]
    d[week_start >= periods$start[j] & week_start <= periods$end[j], period := periods$period[j]]
  }
  stopifnot(!anyNA(d$period))
  periods[, n_weeks := sapply(period, function(p) uniqueN(d[period == p]$week_start))]
  stopifnot(sum(periods$n_weeks) == 209)
  fwrite(periods, file.path(out, 'period_definitions.csv'))
  make_outcomes <- function(z) {
    z <- merge(z, reference[, .(age_group, weight, weight_equal_district)], by='age_group')
    a <- z[, .(geo_code, type, week_start, period, outcome=age_group, value=incidence)]
    total <- z[, .(crude = if (all(is.finite(population)) && all(population>0))
                               sum(cases)/sum(population)*1e5 else NA_real_,
                   standard = if (all(is.finite(incidence))) sum(weight*incidence) else NA_real_,
                   standard_equal = if (all(is.finite(incidence))) sum(weight_equal_district*incidence) else NA_real_),
               by=.(geo_code,type,week_start,period)]
    rbindlist(list(a, melt(total, id.vars=c('geo_code','type','week_start','period'),
                          variable.name='outcome', value.name='value')), use.names=TRUE)
  }
  long <- make_outcomes(d)
  weekly <- long[, .(mean=mean(value), median=median(value), n=.N), by=.(type,week_start,period,outcome)]
  fwrite(weekly, file.path(out, 'weekly_district_rates.csv'))
  pp <- pop[geo_code %in% keep]
  pp[, share := population/sum(population), by=.(geo_code,iso_year)]
  composition <- pp[, .(mean_share=mean(share), n=.N), by=.(iso_year,type,age_group)]
  fwrite(composition, file.path(out, 'age_composition.csv'))
  # Mean weekly rates: the same weeks receive equal weights for every district.
  summary <- rbindlist(list(long[, .(value=mean(value)), by=.(geo_code,type,period,outcome)],
    long[, .(value=mean(value), period='All'), by=.(geo_code,type,outcome)]), use.names=TRUE)
  summary[, key := paste(period,outcome,sep='|')]
  wide <- dcast(summary, geo_code + type ~ key, value.var='value')
  keys <- setdiff(names(wide),c('geo_code','type'))
  stopifnot(!anyNA(wide))
  had_seed <- exists('.Random.seed', envir=.GlobalEnv, inherits=FALSE)
  if (had_seed) old_seed <- get('.Random.seed', envir=.GlobalEnv)
  on.exit(if(had_seed) assign('.Random.seed', old_seed, envir=.GlobalEnv) else
    if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)) rm('.Random.seed',envir=.GlobalEnv), add=TRUE)
  set.seed(seed)
  estimates <- array(NA_real_, c(4,length(keys)), dimnames=list(as.character(1:4),keys))
  reps <- array(NA_real_, c(B,4,length(keys)), dimnames=list(NULL,as.character(1:4),keys))
  for (t in 1:4) {
    m <- as.matrix(wide[type == t, ..keys]); n <- nrow(m)
    estimates[t,] <- colMeans(m)
    # One draw resamples a district's whole age-time vector; draws shared by all contrasts.
    counts <- rmultinom(B, n, rep(1/n,n))/n
    reps[,t,] <- t(counts) %*% m
  }
  inference <- function(theta, draws, relative=FALSE) {
    if (!is.finite(theta) || any(!is.finite(draws)))
      return(list(estimate=if(is.finite(theta)) {if(relative) exp(theta) else theta} else NA_real_,
                  se=NA_real_,lower=NA_real_,upper=NA_real_,p=NA_real_,status='unstable_zero_rate'))
    se <- sd(draws)
    p <- if (se > 0) 2*pnorm(-abs(theta/se)) else if (theta == 0) 1 else 0
    ci <- theta+c(-1,1)*qnorm(.975)*se
    list(estimate=if(relative) exp(theta) else theta, se=se,
         lower=if(relative) exp(ci[1]) else ci[1], upper=if(relative) exp(ci[2]) else ci[2], p=p,status='ok')
  }
  pairs <- combn(1:4,2,simplify=FALSE)
  get_contrast <- function(k,p,scale) {
    if(scale == 'absolute') list(theta=estimates[p[1],k]-estimates[p[2],k],
                                  draws=reps[,p[1],k]-reps[,p[2],k])
    else list(theta=log(estimates[p[1],k]/estimates[p[2],k]),
              draws=log(reps[,p[1],k]/reps[,p[2],k]))
  }
  rows <- list(); z <- 0L
  for(k in keys) for(p in pairs) for(s in c('absolute','relative')) {
    cc <- get_contrast(k,p,s); parts <- strsplit(k,'|',fixed=TRUE)[[1]]
    z<-z+1L; rows[[z]] <- c(list(period=parts[1],outcome=parts[2],type_a=p[1],type_b=p[2],scale=s),
      inference(cc$theta,cc$draws,s=='relative'))
  }
  contrasts <- rbindlist(rows)
  # Families: all 6 pairs across all nine primary outcomes and two scales; periods separately.
  contrasts[, p_holm := NA_real_]
  contrasts[outcome!='standard_equal' & period=='All', p_holm:=p.adjust(p,'holm')]
  contrasts[outcome!='standard_equal' & period!='All', p_holm:=p.adjust(p,'holm')]
  contrasts[outcome=='standard_equal', p_holm:=p.adjust(p,'holm')]
  fwrite(contrasts,file.path(out,'pairwise_contrasts.csv'))
  # Direct age interaction: difference of differences / ratio of rate ratios.
  rows<-list(); z<-0L
  for (period in c('All',periods$period)) for (p in pairs)
    for (ap in combn(ages,2,simplify=FALSE)) for(s in c('absolute','relative')) {
      ca<-get_contrast(paste(period,ap[1],sep='|'),p,s)
      cb<-get_contrast(paste(period,ap[2],sep='|'),p,s)
      z<-z+1L; rows[[z]]<-c(list(period=period,type_a=p[1],type_b=p[2],age_a=ap[1],age_b=ap[2],scale=s),
        inference(ca$theta-cb$theta,ca$draws-cb$draws,s=='relative'))
    }
  interactions<-rbindlist(rows)
  interactions[period=='All',p_holm:=p.adjust(p,'holm')]
  interactions[period!='All',p_holm:=p.adjust(p,'holm')]
  fwrite(interactions,file.path(out,'age_interactions.csv'))
  # Stage differences are tested directly, not inferred from significance in one stage only.
  rows<-list(); z<-0L
  for (tp in combn(periods$period,2,simplify=FALSE)) for(p in pairs)
    for(o in c('standard',ages)) for(s in c('absolute','relative')) {
      ca<-get_contrast(paste(tp[1],o,sep='|'),p,s); cb<-get_contrast(paste(tp[2],o,sep='|'),p,s)
      z<-z+1L; rows[[z]]<-c(list(period_a=tp[1],period_b=tp[2],outcome=o,type_a=p[1],type_b=p[2],scale=s),
        inference(ca$theta-cb$theta,ca$draws-cb$draws,s=='relative'))
    }
  temporal<-rbindlist(rows); temporal[,p_holm:=p.adjust(p,'holm')]
  fwrite(temporal,file.path(out,'period_interactions.csv'))
  # Direct three-way contrasts: is age modification different across stages?
  rows<-list();z<-0L
  for(tp in combn(periods$period,2,simplify=FALSE)) for(p in pairs)
    for(ap in combn(ages,2,simplify=FALSE)) for(s in c('absolute','relative')) {
      ca<-get_contrast(paste(tp[1],ap[1],sep='|'),p,s); cb<-get_contrast(paste(tp[1],ap[2],sep='|'),p,s)
      cc<-get_contrast(paste(tp[2],ap[1],sep='|'),p,s); cd<-get_contrast(paste(tp[2],ap[2],sep='|'),p,s)
      z<-z+1L;rows[[z]]<-c(list(period_a=tp[1],period_b=tp[2],type_a=p[1],type_b=p[2],age_a=ap[1],age_b=ap[2],scale=s),
        inference(ca$theta-cb$theta-cc$theta+cd$theta,ca$draws-cb$draws-cc$draws+cd$draws,s=='relative'))
    }
  threeway<-rbindlist(rows);threeway[,p_holm:=p.adjust(p,'holm')]
  fwrite(threeway,file.path(out,'age_period_interactions.csv'))
  # Descriptive sensitivity: original annual types and all available district-weeks.
  alt<-copy(x);alt[,type:=kreistyp_code]
  sens<-make_outcomes(alt)[,.(mean=mean(value,na.rm=TRUE),n=sum(is.finite(value))),by=.(type,week_start,outcome)]
  fwrite(sens,file.path(out,'sensitivity_available_annual_types.csv'))
  fixed_available<-make_outcomes(x)[,.(mean=mean(value,na.rm=TRUE),n=sum(is.finite(value))),by=.(type,week_start,outcome)]
  fwrite(fixed_available,file.path(out,'sensitivity_available_fixed_types.csv'))
  annual_complete<-copy(d);annual_complete[,type:=kreistyp_code]
  annual_complete<-make_outcomes(annual_complete)[,.(mean=mean(value),n=.N),by=.(type,week_start,outcome)]
  fwrite(annual_complete,file.path(out,'sensitivity_complete_annual_types.csv'))
  # Plot labels intentionally identify means, equal district weights and selected sample.
  labs_type<-c('1 Grossstadt','2 Staedtisch','3 Laendlich verdichtet','4 Duenn laendlich')
  palette<-c('#0072B2','#009E73','#D55E00','#CC79A7')
  old_theme <- theme_get()
  on.exit(theme_set(old_theme), add=TRUE)
  theme_set(theme_minimal(base_size=11)+theme(legend.position='bottom',panel.grid.minor=element_blank(),
    plot.title=element_text(face='bold'),strip.text=element_text(face='bold')))
  weekly[,typ:=factor(type,1:4,labs_type)]
  plot_save<-function(name,p,w=12,h=7) ggsave(file.path(out,paste0(name,'.png')),p,width=w,height=h,dpi=170)
  p<-ggplot(weekly[outcome %in% c('crude','standard')],aes(week_start,mean,color=typ))+
    geom_line(linewidth=.55)+facet_wrap(~outcome,ncol=1)+scale_color_manual(values=palette)+
    labs(title='Gesamtvergleich: rohe und altersstandardisierte Meldeinzidenz',
      subtitle='383 vollstaendige Kreise; gleiche Kreisgewichte; Kreistyp 2023; Standardbevoelkerung 2021',
      x=NULL,y='Faelle je 100.000 / Woche',color=NULL)
  plot_save('01_crude_standard_weekly',p)
  p<-ggplot(weekly[outcome %in% ages],aes(week_start,mean,color=typ))+geom_line(linewidth=.45)+
    facet_wrap(~factor(outcome,levels=ages),ncol=2)+scale_color_manual(values=palette)+
    labs(title='Altersgruppen und Kreistypen im gesamten Wochenverlauf',subtitle='Gleiche Skala; Mittelwerte der 383 vollstaendigen Kreise',
         x=NULL,y='Faelle je 100.000 / Woche',color=NULL)
  plot_save('02_age_weekly',p,13,10)
  p<-ggplot(composition,aes(factor(type,1:4,labs_type),mean_share,fill=factor(age_group,levels=ages)))+
    geom_col()+facet_wrap(~iso_year,ncol=2)+scale_y_continuous(labels=function(x) paste0(round(x*100),'%'))+
    coord_flip()+labs(title='Alterszusammensetzung: mittlere Anteile je Kreis',subtitle='RKI-inferierte Nenner; keine unabhaengige amtliche Altersstruktur',x=NULL,y='Anteil',fill='Alter')
  plot_save('03_age_composition',p,13,8)
  contrasts[,pair:=paste(type_a,type_b,sep=' - ')]
  p<-ggplot(contrasts[period=='All' & outcome %in% c('crude','standard') & scale=='absolute'],
    aes(estimate,pair,color=outcome))+geom_vline(xintercept=0,color='grey65')+
    geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15,position=position_dodge(width=.4))+
    geom_point(position=position_dodge(width=.4))+labs(title='Alle sechs Kreistypvergleiche: roh und standardisiert',
      subtitle='2020-2023: mittlere woechentliche Differenz; punktweise 95%-Intervalle',x='Typ A minus Typ B: Faelle je 100.000 / Woche',y='Typ A - Typ B',color=NULL)
  plot_save('04_overall_absolute',p,11,6)
  p<-ggplot(contrasts[period=='All' & outcome %in% ages & scale=='relative'],aes(estimate,factor(outcome,levels=ages)))+
    geom_vline(xintercept=1,color='grey65')+geom_errorbar(aes(xmin=lower,xmax=upper),orientation='y',width=.15)+
    geom_point()+facet_wrap(~pair,ncol=3)+scale_x_log10()+labs(title='Relative Unterschiede innerhalb der Altersgruppen',
      subtitle='Typ A / Typ B; punktweise 95%-Intervalle; 1 = gleiche mittlere Rate',x='Verhaeltnis der mittleren Wochenraten (Log-Skala)',y='Alter')
  plot_save('05_age_relative',p,12,8)
  p<-ggplot(contrasts[period!='All' & outcome %in% ages & scale=='absolute'],
    aes(factor(period,levels=periods$period),factor(outcome,levels=ages),fill=estimate))+
    geom_tile()+facet_wrap(~pair,ncol=3)+scale_fill_gradient2(low='#542788',mid='white',high='#D55E00')+
    guides(fill=guide_colourbar(barwidth=grid::unit(10,'cm'),barheight=grid::unit(.4,'cm')))+
    theme(axis.text.x=element_text(angle=50,hjust=1))+labs(title='Altersabhaengige Kreistypunterschiede nach Zeitraum',
      subtitle='Typ A minus Typ B; keine Signifikanzmarkierung; PostW5 ist keine einzelne Welle',x=NULL,y='Alter',fill='Differenz')
  plot_save('06_age_period_absolute',p,14,8)
  # Weekly contrasts show short-lived reversals hidden by long-period summaries.
  wc<-dcast(weekly,outcome+week_start~type,value.var='mean')
  wc<-rbindlist(lapply(pairs,function(p) wc[,.(outcome,week_start,pair=paste(p,collapse=' - '),
      difference=get(as.character(p[1]))-get(as.character(p[2])))]))
  fwrite(wc,file.path(out,'weekly_pairwise_differences.csv'))
  p<-ggplot(wc[outcome %in% ages],aes(week_start,difference,color=factor(outcome,levels=ages)))+
    geom_hline(yintercept=0,color='grey65')+geom_line(linewidth=.4)+facet_wrap(~pair,ncol=2)+
    labs(title='Wann aendert sich die Richtung der Unterschiede?',subtitle='Woechentliche Differenzen; deskriptiv, ohne woechentliche Tests',
         x=NULL,y='Typ A minus Typ B / 100.000',color='Alter')
  plot_save('07_weekly_pairwise_differences',p,13,10)
  fwrite(data.table(type=1:4,n=sapply(1:4,function(t) nrow(wide[type==t]))),file.path(out,'sample_sizes.csv'))
  saveRDS(list(estimates=estimates,bootstrap=reps,seed=seed,B=B),file.path(out,'bootstrap_draws.rds'),compress='xz')
  writeLines(trimws(capture.output(sessionInfo()), which='right'), file.path(out,'sessionInfo.txt'))
  writeLines(c(paste('Completed:',Sys.time()),paste('Input MD5:',tools::md5sum(input)),
               paste('Districts:',length(keep)),paste('Bootstrap draws:',B),paste('Seed:',seed)),file.path(out,'RUN_COMPLETE.txt'))
  message('COMPLETE: ',out,'; ',length(keep),' districts; ',B,' cluster-bootstrap draws.')
  invisible(list(contrasts=contrasts,interactions=interactions,temporal=temporal,threeway=threeway))
}
results <- run_analysis()
