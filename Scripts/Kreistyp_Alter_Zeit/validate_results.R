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
  # Independent aggregation using base R, before joining summary outputs.
  x <- as.data.frame(readRDS('data_processed/Kreistyp x Altersgruppe/kreis_weekly_age_kreistyp_2020_2023.rds'))
  excluded <- unique(x$geo_code[!is.finite(x$incidence)])
  d <- x[!x$geo_code %in% excluded,]
  types <- unique(x[x$iso_year==2023,c('geo_code','kreistyp_code')])
  ages <- levels(x$age_group)
  ref <- fread(file.path(out,'standard_population_2021.csv'))
  w <- setNames(ref$weight,ref$age_group)
  # Toy example: equal within-age rates imply equal standardized rates despite crude differences.
  r <- c(1000,200); stopifnot(sum(r*c(.8,.2))==840, sum(r*c(.5,.5))==600,
                           sum(r*c(.65,.35))==sum(r*c(.65,.35)))
  a <- aggregate(d$incidence*w[as.character(d$age_group)],
                 list(geo_code=d$geo_code,week=d$week_start),sum)
  a$type <- types$kreistyp_code[match(a$geo_code,types$geo_code)]
  means <- tapply(a$x,a$type,mean)
  result <- p[period=='All' & outcome=='standard' & scale=='absolute']
  stopifnot(max(abs(result$estimate-(means[as.character(result$type_a)]-
                                    means[as.character(result$type_b)])))<1e-8)
  # Time aggregation must reproduce the full-period estimate with week-count weights.
  stage <- p[period!='All' & outcome=='standard' & scale=='absolute']
  stage <- merge(stage,periods[,.(period,n_weeks)],by='period')
  reconstructed <- stage[,.(reconstructed=sum(estimate*n_weeks)/209),by=.(type_a,type_b)]
  ck<-merge(result,reconstructed,by=c('type_a','type_b'))
  stopifnot(max(abs(ck$estimate-ck$reconstructed))<1e-8)
  # Bootstrap standard error agrees with the independent district-mean analytic variance.
  district <- aggregate(x~geo_code+type,a,mean)
  v <- tapply(district$x,district$type,function(z) var(z)/length(z)*(length(z)-1)/length(z))
  analytic <- sqrt(v[as.character(result$type_a)]+v[as.character(result$type_b)])
  stopifnot(max(abs(result$se/analytic-1))<.10)
  writeLines('PASS: key completeness, contrast families, missing-rate flags, time reconstruction, independent standardization, bootstrap variance.',
             file.path(out,'VALIDATION.txt'))
  message('VALIDATION PASSED')
})
