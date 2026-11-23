suppressPackageStartupMessages(library(data.table))
local({
  out <- 'results/Kreistyp_Alter_Zeit'
  p <- fread(file.path(out,'pairwise_contrasts.csv'))
  stopifnot(all(p[, .N, by=.(period,outcome,scale)]$N == 6L))
  stopifnot(all(p[status=='ok', lower <= estimate & estimate <= upper]),
            all(p[is.finite(p_holm), p_holm >= p - 1e-12]),
            all(p[status!='ok', period == 'P0' & scale == 'relative']))
  periods <- fread(file.path(out,'period_definitions.csv'))
  stopifnot(sum(periods$n_weeks)==209L)
  # Unabhängige Aggregation mit Basis-R vor dem Vergleich mit den Ergebnistabellen.
  x <- as.data.frame(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
  excluded <- unique(x$geo_code[!is.finite(x$incidence)])
  d <- x[!x$geo_code %in% excluded,]
  types <- unique(d[c('geo_code','week_start','kreistyp_code')])
  ages <- levels(x$age_group)
  ref <- fread(file.path(out,'standard_population_2021.csv'))
  w <- setNames(ref$weight,ref$age_group)
  # Rechenbeispiel: gleiche altersspezifische Raten, unterschiedliche rohe Raten.
  r <- c(1000,200); stopifnot(sum(r*c(.8,.2))==840, sum(r*c(.5,.5))==600,
                           sum(r*c(.65,.35))==sum(r*c(.65,.35)))
  a <- aggregate(d$incidence*w[as.character(d$age_group)],
                 list(geo_code=d$geo_code,week=d$week_start),sum)
  a <- merge(a,types,by.x=c('geo_code','week'),by.y=c('geo_code','week_start'))
  a$type <- a$kreistyp_code
  wm <- aggregate(x~week+type,a,mean)
  means <- tapply(wm$x,wm$type,mean)
  result <- p[period=='All' & outcome=='standard' & scale=='absolute']
  stopifnot(max(abs(result$estimate-(means[as.character(result$type_a)]-
                                    means[as.character(result$type_b)])))<1e-8)
  # Gewichtung nach Wochenzahl muss das Ergebnis des Gesamtzeitraums reproduzieren.
  stage <- p[period!='All' & outcome=='standard' & scale=='absolute']
  stage <- merge(stage,periods[,.(period,n_weeks)],by='period')
  reconstructed <- stage[,.(reconstructed=sum(estimate*n_weeks)/209),by=.(type_a,type_b)]
  ck<-merge(result,reconstructed,by=c('type_a','type_b'))
  stopifnot(max(abs(ck$estimate-ck$reconstructed))<1e-8)
  # Drei Bootstrap-Ziehungen unabhängig aus den vollständigen Wochenwerten prüfen.
  boot <- readRDS(file.path(out,'bootstrap_draws.rds'))
  for(j in 1:3) {
    a$weight <- boot$counts[match(a$geo_code,boot$ids),j]
    a$weighted <- a$x*a$weight
    numer <- aggregate(weighted~week+type,a,sum)
    denom <- aggregate(weight~week+type,a,sum)
    sampled <- merge(numer,denom,by=c('week','type'))
    sampled$rate <- sampled$weighted/sampled$weight
    actual <- tapply(sampled$rate,sampled$type,mean)
    stopifnot(max(abs(actual-boot$bootstrap[j,,'All|standard']))<1e-8)
  }
  writeLines('BESTANDEN: Schlüssel, Vergleichsfamilien, fehlende Raten, Zeitaggregation, unabhängige Standardisierung und jährliche Zuordnung und Bootstrap-Ziehungen.',
             file.path(out,'VALIDATION.txt'))
  message('PRÜFUNGEN BESTANDEN')
})
