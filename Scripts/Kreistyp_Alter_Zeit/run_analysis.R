# Im Projektverzeichnis in einer eigenen Umgebung ausführen:
# covid_age_time <- new.env(); sys.source('Scripts/Kreistyp_Alter_Zeit/run_analysis.R', covid_age_time)
# Deskriptive Inferenz mit gleichen Kreisgewichten; Eingabedaten bleiben unverändert.
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
  x[, type := kreistyp_code]
  keep <- setdiff(unique(x$geo_code), missing$geo_code)
  d <- x[geo_code %in% keep]
  stopifnot(length(keep) == 383L, all(is.finite(d$incidence)))
  fwrite(unique(x[, .(geo_code, geo_name, iso_year, type)])[, included := geo_code %in% keep],
         file.path(out, 'audit_district_sample.csv'))
  # Für 2021 liegen vollständige Nenner aller sieben Altersgruppen und 400 Kreise vor.
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
  # Nicht überlappende Zeiträume einschließlich der Zwischenphasen; alle Wochen bleiben enthalten.
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
  # Jährliche Zugehörigkeit; jede Woche erhält dasselbe Gewicht.
  long <- merge(long, unique(d[, .(week_start, iso_year)]), by='week_start')
  blocks <- unique(long[, .(iso_year, period, week_start)])[, .(n_weeks=.N), by=.(iso_year,period)]
  outcomes <- sort(unique(long$outcome))
  keys <- sort(as.vector(outer(c('All',periods$period), outcomes, paste, sep='|')))
  ids <- sort(unique(long$geo_code))
  had_seed <- exists('.Random.seed', envir=.GlobalEnv, inherits=FALSE)
  if (had_seed) old_seed <- get('.Random.seed', envir=.GlobalEnv)
  on.exit(if(had_seed) assign('.Random.seed', old_seed, envir=.GlobalEnv) else
    if(exists('.Random.seed',envir=.GlobalEnv,inherits=FALSE)) rm('.Random.seed',envir=.GlobalEnv), add=TRUE)
  set.seed(seed)
  counts <- rmultinom(B, length(ids), rep(1/length(ids),length(ids)))
  estimates <- array(0, c(4,length(keys)), dimnames=list(as.character(1:4),keys))
  reps <- array(0, c(B,4,length(keys)), dimnames=list(NULL,as.character(1:4),keys))
  summary <- long[, .(value=mean(value)), by=.(geo_code,type,iso_year,period,outcome)]
  for (j in seq_len(nrow(blocks))) {
    yr <- blocks$iso_year[j]; per <- blocks$period[j]; nw <- blocks$n_weeks[j]
    wide <- dcast(summary[iso_year==yr & period==per],geo_code+type~outcome,value.var='value')
    stopifnot(!anyNA(wide), nrow(wide)==length(ids))
    for(t in 1:4) {
      part <- wide[type==t]
      m <- as.matrix(part[, ..outcomes])
      draw_weights <- counts[match(part$geo_code,ids),,drop=FALSE]
      stopifnot(all(colSums(draw_weights)>0))
      draws <- (t(draw_weights) %*% m)/colSums(draw_weights)
      for(target in c(per,'All')) {
        weight <- nw / if(target=='All') 209 else periods[period==target,n_weeks]
        kk <- paste(target,outcomes,sep='|')
        estimates[t,kk] <- estimates[t,kk]+weight*colMeans(m)
        reps[,t,kk] <- reps[,t,kk]+weight*draws
      }
    }
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
  # Testfamilien: sechs Paare, neun primäre Zielgrößen und zwei Skalen; Zeiträume separat.
  contrasts[, p_holm := NA_real_]
  contrasts[outcome!='standard_equal' & period=='All', p_holm:=p.adjust(p,'holm')]
  contrasts[outcome!='standard_equal' & period!='All', p_holm:=p.adjust(p,'holm')]
  contrasts[outcome=='standard_equal', p_holm:=p.adjust(p,'holm')]
  fwrite(contrasts,file.path(out,'pairwise_contrasts.csv'))
  # Direkte Altersinteraktion: Differenz der Differenzen bzw. Verhältnis der Ratenverhältnisse.
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
  # Zeitraumunterschiede direkt testen; unterschiedliche Einzelsignifikanz genügt nicht.
  rows<-list(); z<-0L
  for (tp in combn(periods$period,2,simplify=FALSE)) for(p in pairs)
    for(o in c('standard',ages)) for(s in c('absolute','relative')) {
      ca<-get_contrast(paste(tp[1],o,sep='|'),p,s); cb<-get_contrast(paste(tp[2],o,sep='|'),p,s)
      z<-z+1L; rows[[z]]<-c(list(period_a=tp[1],period_b=tp[2],outcome=o,type_a=p[1],type_b=p[2],scale=s),
        inference(ca$theta-cb$theta,ca$draws-cb$draws,s=='relative'))
    }
  temporal<-rbindlist(rows); temporal[,p_holm:=p.adjust(p,'holm')]
  fwrite(temporal,file.path(out,'period_interactions.csv'))
  # Dreifachkontraste: Verändert sich die Altersinteraktion zwischen Zeiträumen?
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
  # Deskriptive Sensitivitätsanalyse: jährliche Kreistypen und verfügbare Kreiswochen.
  alt<-copy(x);alt[,type:=kreistyp_code]
  sens<-make_outcomes(alt)[,.(mean=mean(value,na.rm=TRUE),n=sum(is.finite(value))),by=.(type,week_start,outcome)]
  fwrite(sens,file.path(out,'sensitivity_available_annual_types.csv'))
  fixed_x <- copy(x); fixed_x[,type:=fixed$type[match(geo_code,fixed$geo_code)]]
  fixed_available<-make_outcomes(fixed_x)[,.(mean=mean(value,na.rm=TRUE),n=sum(is.finite(value))),by=.(type,week_start,outcome)]
  fwrite(fixed_available,file.path(out,'sensitivity_available_fixed_types.csv'))
  annual_complete<-copy(d);annual_complete[,type:=kreistyp_code]
  annual_complete<-make_outcomes(annual_complete)[,.(mean=mean(value),n=.N),by=.(type,week_start,outcome)]
  fwrite(annual_complete,file.path(out,'sensitivity_complete_annual_types.csv'))
  fixed_complete <- make_outcomes(fixed_x[geo_code %in% keep])[,.(mean=mean(value),n=.N),by=.(type,week_start,outcome)]
  fwrite(fixed_complete,file.path(out,'sensitivity_complete_fixed_types.csv'))
  # Wöchentliche Differenzen für sämtliche Paarvergleiche speichern.
  wc <- dcast(weekly,outcome+week_start~type,value.var='mean')
  wc <- rbindlist(lapply(pairs,function(p) wc[,.(outcome,week_start,pair=paste(p,collapse=' - '),
    difference=get(as.character(p[1]))-get(as.character(p[2])))]))
  fwrite(wc,file.path(out,'weekly_pairwise_differences.csv'))
  sys.source('Scripts/Kreistyp_Alter_Zeit/abbildungen.R', envir=new.env())
  fwrite(unique(d[,.(geo_code,iso_year,type)])[,.(n=.N),by=.(iso_year,type)],file.path(out,'sample_sizes.csv'))
  saveRDS(list(estimates=estimates,bootstrap=reps,counts=counts,ids=ids,seed=seed,B=B),file.path(out,'bootstrap_draws.rds'),compress='xz')
  writeLines(trimws(capture.output(sessionInfo()), which='right'), file.path(out,'sessionInfo.txt'))
  writeLines(c(paste('Abgeschlossen:',Sys.time()),paste('MD5 der Eingabe:',tools::md5sum(input)),
               paste('Kreise:',length(keep)),paste('Bootstrap-Ziehungen:',B),paste('Zufallsstartwert:',seed)),file.path(out,'RUN_COMPLETE.txt'))
  message('ABGESCHLOSSEN: ',out,'; ',length(keep),' Kreise; ',B,' Kreis-Bootstrap-Ziehungen.')
  invisible(list(contrasts=contrasts,interactions=interactions,temporal=temporal,threeway=threeway))
}
results <- run_analysis()
