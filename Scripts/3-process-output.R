#################
# Process model output
#
# Author: Casey Youngflesh
#################


# Clear environment -------------------------------------------------------

rm(list = ls())


# Load packages -----------------------------------------------------------

library(MCMCvis)
library(boot)
library(dplyr)


# Load model results and data -------------------------------------------------------

#phi = survival prob
#p = detection prob


NAME <- 'PW_400k_2020-03-16'
OUTPUT <- '~/Google_Drive/R/penguin_watch_model/Results/OUTPUT-2020-03-16'

setwd(paste0('~/Google_Drive/R/penguin_watch_model/Results/', NAME))

fit <- readRDS(paste0(NAME, '.rds'))
data <- readRDS('jagsData.rds')

setwd('~/Google_Drive/R/penguin_watch_model/Data/PW_data/')
PW_data <- read.csv('PW_data_2019-10-07.csv', stringsAsFactors = FALSE)


# model summary ---------------------------------------------------------------

sm <- MCMCvis::MCMCsummary(fit, excl = c('z_out', 'p_out'))


# trace plots -------------------------------------------------------------

#create dir for figs if doesn't exist
ifelse(!dir.exists(OUTPUT), 
       dir.create(OUTPUT), 
       FALSE)

setwd(OUTPUT)


MCMCvis::MCMCtrace(fit, params = 'nu_p', Rhat = TRUE, n.eff = TRUE,
                   ind = TRUE, filename = 'nu_p_trace.pdf', 
                   open_pdf = FALSE)
MCMCvis::MCMCtrace(fit, params = 'beta_p', Rhat = TRUE, n.eff = TRUE,
                   ind = TRUE, filename = 'beta_p_trace.pdf',
                   open_pdf = FALSE)
MCMCvis::MCMCtrace(fit, params = 'mu_phi', Rhat = TRUE, n.eff = TRUE,
                   ind = TRUE, filename = 'mu_phi_trace.pdf',
                   open_pdf = FALSE)


# PPO ---------------------------------------------------------------------

setwd(OUTPUT)

tf <- function(PR)
{
  hist(boot::inv.logit(PR))
}


# mu_p ~ dnorm(0, 0.1)
PR <- rnorm(15000, 0, 1/sqrt(0.1))
# tf(PR)
MCMCvis::MCMCtrace(fit, 
          params = 'mu_p',
          ind = TRUE, 
          priors = PR,
          filename = 'mu_p_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)


# mu_beta_p ~ dnorm(0.1, 10) T(0, 1)
PR_p <- rnorm(15000, 0.1, 1/sqrt(10))
PR <- PR_p[which(PR_p > 0 & PR_p < 1)]
# tf(PR)
MCMCvis::MCMCtrace(fit, 
          params = 'mu_beta_p',
          ind = TRUE, 
          priors = PR,
          filename = 'mu_beta_p_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)

# sigma_beta_p ~ dunif(0, 2)
PR <- runif(15000, 0, 2)
MCMCvis::MCMCtrace(fit, 
          params = 'sigma_beta_p',
          ind = TRUE, 
          priors = PR,
          filename = 'sigma_beta_p_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)

# sigma_nu_p ~ dunif(0, 3)
PR <- runif(15000, 0, 3)
MCMCvis::MCMCtrace(fit, 
          params = 'sigma_nu_p',
          ind = TRUE, 
          priors = PR,
          filename = 'sigma_nu_p_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)

# theta_phi ~ dnorm(4, 0.25)
PR <- rnorm(15000, 4, 1/sqrt(0.25))
# tf(PR)
MCMCvis::MCMCtrace(fit, 
          params = 'theta_phi',
          ind = TRUE, 
          priors = PR,
          filename = 'theta_phi_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)

# sigma_mu_phi ~ dunif(0, 3)
PR <- runif(15000, 0, 3)
MCMCvis::MCMCtrace(fit, 
          params = 'sigma_mu_phi',
          ind = TRUE, 
          priors = PR,
          filename = 'sigma_mu_phi_PPO.pdf',
          post_zm = FALSE,
          open_pdf = FALSE)


# aggregate precip events to day ------------------------------------------

#sum rain and max snow

setwd('~/Google_Drive/R/penguin_watch_model/Data/precip_data')

fls <- list.files()

precip_df <- data.frame()
for (k in 1:length(data$unsites))
{
  #k <- 1
  fls2 <- fls[grep(data$unsites[k], fls)]
  
  years <- as.numeric(substr(fls2, start = 6, stop = 9))
  for (j in 1:length(years))
  {
    #j <- 1
    
    #read in csv for that site/year
    tt <- read.csv(fls2[grep(years[j], fls2)])
    
    #remove time and transform to date
    dates <- as.Date(sapply(strsplit(as.character(tt$datetime), 
                                     split = ' '), '[', 1), 
                     format = '%Y:%m:%d')
    
    udates <- unique(dates)
    for (i in 1:length(udates))
    {
      #i <- 1
      t2 <- tt[which(dates == udates[i]),]
      
      #max snow score
      t_snow <- t2$score[grep('S', t2$score)]
      if (length(t_snow) > 0)
      {
        m_snow <- max(as.numeric(substr(t_snow, start = 2, stop = 2)))
      } else {
        m_snow <- 0
      }
      
      #rain
      t_rain <- t2$score[grep('R', t2$score)]
      if (length(t_rain) > 0)
      {
        s_rain <- sum(as.numeric(substr(t_rain, start = 2, stop = 2)))
      } else {
        s_rain <- 0
      }
      
      t_precip <- data.frame(site = data$unsites[k],
                             season_year = years[j],
                             date = udates[i],
                             m_snow,
                             s_rain)
      
      precip_df <- rbind(precip_df, t_precip)
    }
  }
}


# merge precip data with model output ----------------------------------------------------------

#extract BS data from model output

#mu_phi_bs
bs <- MCMCvis::MCMCpstr(fit, params = 'bs', func = mean)[[1]]
bs_sd <- MCMCvis::MCMCpstr(fit, params = 'bs', func = sd)[[1]]


p2 <- data.frame()
for (k in 1:length(data$unsites))
{
  #k <- 1
  tsite <- dplyr::filter(precip_df, site == data$unsites[k])
  
  u_year <- unique(tsite$season_year)
  for (j in 1:length(u_year))
  {
    #j <- 1
    tyear <- dplyr::filter(tsite, season_year == u_year[j])
    tsnow <- length(which(tyear$m_snow >= 2))
    train <- length(which(tyear$s_rain >= 2))
    
    tt <- data.frame(SITE = data$unsites[k], 
                     YEAR = u_year[j],
                     tsnow,
                     train)
    p2 <- rbind(p2, tt)
  }
}


yrs_rng <- range(data$yrs_array, na.rm = TRUE)

site_vec <- c()
year_vec <- c()
for (k in 1:length(data$unsites))
{
  #k <- 1
  tv <- rep(data$unsites[k], sum(!is.na(data$yrs_array[,k])))
  yv <- data$yrs_array[which(!is.na(data$yrs_array[,k])),k]
  
  site_vec <- c(site_vec, tv)
  year_vec <- c(year_vec, yv)
}

mrg2 <- data.frame(SITE = site_vec,
                   YEAR = year_vec,
                   mn_bs = as.vector(bs)[!is.na(as.vector(bs))],
                   sd_bs = as.vector(bs_sd)[!is.na(as.vector(bs_sd))])


#merge lat/ln with precip, BS, and creche date
cll <- unique(PW_data[,c('site', 'col_lat', 'col_lon')])
mrg3 <- dplyr::left_join(mrg2, cll, by = c('SITE' = 'site'))
mrg4 <- dplyr::left_join(mrg3, p2, by = c('SITE', 'YEAR'))
mrg5 <- dplyr::left_join(mrg4, data$d_mrg, by = c('SITE' = 'site', 'YEAR' = 'season_year'))


# merge with published BS values ------------------------------------------

#Merge with Hinke et al. 2017 (MEE) data
hinke_2017 <- data.frame(SITE = c('SHIR', 'CIER', 'LLAN', 'GALE', 'LION', 'PETE'), 
                         YEAR = rep(2017, 6),
                         mn_bs = c(1.63, 1.47, 1.53, 1.46, 1.26, 1.51),
                         sd_bs = rep(NA, 6),
                         col_lat = c(-62.46, -64.143, -62.175, 
                                     -65.244, -62.135, -65.17),
                         col_lon = c(-60.789, -60.984, -58.456, 
                                     -64.247, -58.126, -64.14),
                         tsnow = rep(NA, 6),
                         train = rep(NA, 6),
                         j = rep(NA, 6),
                         k = rep(NA, 6),
                         num_nests = c(8, 15, 58, 28, 19, 37),
                         chick_date = rep(NA, 6),
                         creche_date = c('2017-01-18', '2017-01-20', '2016-12-22',
                                         '2017-02-04', '2016-12-20', '2017-02-08'),
                         days = rep(NA, 6))

#merge with Lynch et al. 2009 (Polar Bio) data
lynch_2009 <- data.frame(SITE = 'PETE', 
                         YEAR = c('2004', '2005', '2006', '2007', '2008'),
                         mn_bs = c((3260/2145), (2781/2265), (3453/2438),
                                       (3343/2293), (3348/2719)),
                         sd_bs = rep(NA, 5),
                         col_lat = rep(-65.17, 5),
                         col_lon = rep(-64.14, 5),
                         tsnow = rep(NA, 5),
                         train = rep(NA, 5),
                         j = rep(NA, 5),
                         k = rep(NA, 5),
                         num_nests = c(2145, 2265, 2438, 2293, 2719),
                         chick_date = rep(NA, 5),
                         creche_date = rep(NA, 5),
                         days = rep(NA, 5))

#From Lynch et al. 2009 (Polar Bio)
#LOCK - 1.24 - 1.39 - Cobley and Shears 1999
#BIRD ISLAND - 0 - 1.2 - Croxall and Prince 1979
#BIRD ISLAND - 0.9 - 1.02 - Williams 1990
#MACQUARIE - 0.93 +- 0.45 - Holmes et al. 2006
#MACQUARIE - 0.36 - 1.14 - Reilly and Kerle 1981
#MACQUARIE - 0 - 1.52 - Robertson 1986

mrg6 <- rbind(mrg5, hinke_2017, lynch_2009)

mrg6$SOURCE <- c(rep('PW', length(which(!is.na(mrg6$train)))), 
                 rep('Hinke', length(which(is.na(mrg6$train) & !is.na(mrg6$creche_date)))),
                 rep('Lynch', length(which(is.na(mrg6$creche_date)))))


# save master object ------------------------------------------------------

setwd(OUTPUT)

mrg6$YEAR <- as.numeric(mrg6$YEAR)
saveRDS(mrg6, 'bs_precip_mrg.rds')


# save z_out and p_out ----------------------------------------------------

setwd(OUTPUT)

z_out_obj <- MCMCvis::MCMCchains(fit, params = 'z_out', mcmc.list = TRUE)
p_out_obj <- MCMCvis::MCMCchains(fit, params = 'p_out', mcmc.list = TRUE)
sy_chicks_rep_obj <- MCMCvis::MCMCchains(fit, params = 'sy_chicks_rep', 
                                         mcmc.list = TRUE)

saveRDS(z_out_obj, 'z_out.rds')
saveRDS(p_out_obj, 'p_out.rds')
saveRDS(sy_chicks_rep_obj, 'sy_chicks_rep.rds')
saveRDS(precip_df, 'precip_df.rds')
saveRDS(data, 'jagsData.rds')
