################################################################################
rm(list = ls())

library("rsurvstat")

################################################################################
years = 2020:2024

# Ladem vpn Basisdaten, um die Tage zu erhalten
t.base = get_timeseries(disease = diseases$`COVID-19`,
                        measure = "Count",
                        age_group = age_groups$single_year,
                        age_range = c(0,2),
                        years = years,
                        geography = FedStateKey71Map[1,],
                        trim_zeros = "none")
  # sortieren
  t.base = t.base[order(t.base$date, t.base$year),]

ret.array = array(NA, dim = c(82,411,nrow(t.base)), dimnames = list(c(0:79,"80+","NA"), CountyKey71Map$Name, unique(paste(t.base$date, t.base$year, sep = "_"))))
inz.array = ret.array

for (i in 1:411){
    tt = get_timeseries(disease = diseases$`COVID-19`,
                        measure = "Count",
                        age_group = age_groups$single_year,
                        years = years,
                        geography = CountyKey71Map[i,],
                        trim_zeros = "none")
      tt$age_name[is.na(tt$age_name)] = "NA"
      tt$age_name                     = factor(tt$age_name, levels = c(0:79,"80+","NA"))
      tt                              = tt[order(tt$date, tt$year, tt$age_name, tt$age_name),]
      tt$data_year                    = paste(tt$date, tt$year, sep = "_") 
      tt.tab = matrix(tt$count, nrow = nrow(ret.array[,1,]), ncol = ncol(ret.array[,1,]))
      ret.array[,i,] = tt.tab
    # Inzidenz
    ti = get_timeseries(disease = diseases$`COVID-19`,
                        measure = "Incidence",
                        age_group = age_groups$single_year,
                        years = years,
                        geography = CountyKey71Map[i,],
                        trim_zeros = "none")
      ti$age_name[is.na(ti$age_name)] = "NA"
      ti$age_name                     = factor(ti$age_name, levels = c(0:79,"80+","NA"))
      ti                              = ti[order(ti$date, ti$year, ti$age_name, ti$age_name),]
      ti$data_year                    = paste(ti$date, ti$year, sep = "_") 
      ti.tab = matrix(ti$incidence, nrow = nrow(ret.array[,1,]), ncol = ncol(ret.array[,1,]))
      inz.array[,i,] = ti.tab
    print(i)
}

saveRDS(ret.array, "Count_COVID_LK_Week_RKI_2020_2024.RData")
saveRDS(inz.array, "Incidence_COVID_LK_Week_RKI_2020_2024.RData")
################################################################################
# Bevölkerung

ret.bev = infer_population(age_group = age_groups$single_year,
                           geography = "county",
                           years = years,
                           .progress = TRUE
)

saveRDS(ret.bev, "Count_Bev_LK_RKI_2020_2024.RData")

write.csv(ret.bev[,c("geo_name","age_name","year","population")], "Count_Bev_LK_RKI_2020_2024.csv")
################################################################################
# ret.array und inz.array umformen und als csv speichern
ret.dat = as.data.frame(ret.array[,1,])
  ret.dat$geo.name = dimnames(ret.array)[[2]][1]
inz.dat = as.data.frame(inz.array[,1,])
  inz.dat$geo.name = dimnames(inz.array)[[2]][1]
  for (i in 2:(dim(ret.array))[2]){
    t.c.dat = as.data.frame(ret.array[,i,])
      t.c.dat$geo.name = dimnames(ret.array)[[2]][i]
      ret.dat = rbind(ret.dat,t.c.dat)
    t.i.dat = as.data.frame(inz.array[,i,])
      t.i.dat$geo.name = dimnames(inz.array)[[2]][i]
      inz.dat = rbind(inz.dat,t.i.dat)
  }

write.csv(ret.dat, file = "Count_COVID_LK_Week_RKI_2020_2024.csv")
write.csv(inz.dat, file = "Incidence_COVID_LK_Week_RKI_2020_2024.csv")
