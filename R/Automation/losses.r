tryCatch(detach("package:do", unload=TRUE), error=function(e) NULL)

get_os <- function(){
  sysinf <- Sys.info()
  if (!is.null(sysinf)){
    os <- sysinf['sysname']
    if (os == 'Darwin')
      os <- "osx"
  } else { ## mystery machine
    os <- .Platform$OS.type
    if (grepl("^darwin", R.version$os))
      os <- "osx"
    if (grepl("linux-gnu", R.version$os))
      os <- "linux"
  }
  tolower(os)
}

list.of.packages <- c("ggplot2", "RCurl", "reshape2", "data.table", "gsheet", "tidyverse", "lubridate", "scales", "rvest", "sf", "mapview", "raster", "ggmap", "dplyr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(get_os()!="linux"){
  if(length(new.packages)) lapply(new.packages, function(x) install.packages(x, repos="http://cran.rstudio.com/", dep = TRUE, ask=FALSE, type="binary"))
} else if(get_os()=="linux"){
  if(length(new.packages)) lapply(new.packages, function(x) install.packages(x, repos="http://cran.rstudio.com/", dep = TRUE, ask=FALSE, type="source"))
}


library(ggplot2)
library(RCurl)
library(reshape2)
library(data.table)
library(gsheet)
library(tidyverse)
library(lubridate)
library(scales)
library(rvest)
library(sf)
library(mapview)
library(raster)
library(ggmap)
library(dplyr)
library(zoo)

country_colors <-   c("Israel" = "#1430A9", "Hamas" = "#31711D")


ggplot2::theme_set(ggplot2::theme_minimal())
# options(ggplot2.continuous.fill  = function() scale_fill_viridis_c())
# options(ggplot2.continuous.colour = function() scale_color_viridis_c())
# options(ggplot2.discrete.colour = function() scale_color_brewer(palette = "Dark2"))
# options(ggplot2.discrete.fill = function() scale_fill_brewer(palette = "Dark2"))



equipment_losses <- read.csv("~/GitHub/Israel-Hamas/data/current_totals.csv")
equipment_losses$Date <- as.Date(equipment_losses$Date)
equipment_totals <- read.csv("~/GitHub/Israel-Hamas/data/current_totals.csv")
equipment_totals$Date <- as.Date(equipment_totals$Date)



####Totals
total_melt <- melt(equipment_losses[,c("Date", "Israel_Total", "Hamas_Total")], id.var="Date")
total_melt$Date <- as.Date(total_melt$Date, format="%m/%d/%Y")
colnames(total_melt) <- c("Date", "Country", "Total")
total_melt$Country <- gsub("_Total", "", total_melt$Country)
total_melt <- total_melt %>%
  group_by(Country) %>%
  arrange(Date) %>%
  mutate(Daily = Total - lag(Total, default = first(Total)))

current_total <- 
  ggplot(total_melt, aes(Date, Total, colour=Country)) +
  geom_col(data=total_melt, mapping=aes(Date, Daily, colour=Country,  fill=Country), alpha=0.8, position = position_dodge(0.7)) + 
  geom_point(show.legend=FALSE, size=0.1) +
  geom_line(stat="smooth", method="gam", size=1, linetype="solid", alpha=0.5, show.legend=FALSE) + 
  scale_x_date(date_labels = "%Y/%m/%d") +
  scale_y_continuous("Total Equipment Losses") +
  ggtitle(paste0("Total equipment losses through ", Sys.Date())) +
  theme_light() + 
  scale_colour_manual(values = country_colors)  + 
  scale_fill_manual(values = country_colors)
ggsave("~/Github/Israel-Hamas/Plots/current_total.jpg", current_total, device="jpg", width=6, height=5)

####Totals Ratio
total_ratio_frame <- data.frame(Date=equipment_losses$Date, Ratio=equipment_losses$Israel_Total/equipment_losses$Hamas_Total)
total_ratio_frame$Date <- as.Date(total_ratio_frame$Date, format="%m/%d/%Y")
total_ratio_frame <- total_ratio_frame %>%
  arrange(Date) %>%
  mutate(Daily = Ratio - lag(Ratio, default = first(Ratio)))

current_ratio <-
  ggplot(total_ratio_frame, aes(Date, Ratio)) +
  geom_col(data=total_ratio_frame, mapping=aes(Date, Daily), alpha=0.8, position = position_dodge(0.7)) +
  geom_point(show.legend=FALSE, size=0.1) +
  geom_line(stat="smooth", method="gam", size=1, linetype="solid", alpha=0.5, show.legend=FALSE) +
  scale_x_date(date_labels = "%Y/%m/%d") +
  scale_y_continuous("Total Equipment Loss Ratio Isr:Hms", breaks = function(x) unique(floor(pretty(seq(0, (max(x) + 1) * 1.1))))) +
  ggtitle(paste0("Total equipment loss ratio through ", Sys.Date())) +
  theme_light()
ggsave("~/Github/Israel-Hamas/Plots/current_ratio.jpg", current_ratio, device="jpg", width=6, height=5)

###Map
ggmap::register_google(key = maps_key)

firms <- read.csv("https://firms.modaps.eosdis.nasa.gov/data/active_fire/noaa-20-viirs-c2/csv/J1_VIIRS_C2_Russia_Asia_24h.csv")
write.csv(firms, paste0("~/GitHub/Israel-Hamas/data/FIRMS/", Sys.Date(), ".csv"))
#firms <- firms[firms$latitude < 52.3 & firms$latitude > 44.1 & firms$longitude < 40.3 & firms$latitude > 26,]
colnames(firms)[1] <- "lat"
colnames(firms)[2] <- "lon"
firms$NASA <- "FIRMS"

###Northern Donbass
gaza <- ggmap::get_map(location=c(lon=34.4, lat=31.4), source="google", maptype="roadmap", crop=FALSE, zoom=10)

gaza_map <- ggmap(gaza) +
  #geom_point(data=btgs, mapping=aes(x=lon, y=lat, shape=Russian_BTGS), alpha=0.9, colour="purple") +
  geom_point(data=firms, mapping=aes(x=lon, y=lat, colour=NASA), alpha=0.5) +
  ggtitle(paste0("Gaza region on ", Sys.Date())) + theme_light()

ggsave("~/Github/Israel-Hamas/Maps/gaza_map.jpg", gaza_map, device="jpg", width=6, height=5, dpi=600)

###Lebanon
lebanon <- ggmap::get_map(location=c(lon=35.4, lat=33.1), source="google", maptype="roadmap", crop=FALSE, zoom=10)

lebanon_map <- ggmap(lebanon) +
#geom_point(data=btgs, mapping=aes(x=lon, y=lat, shape=Russian_BTGS), alpha=0.9, colour="purple") +
geom_point(data=firms, mapping=aes(x=lon, y=lat, colour=NASA), alpha=0.5) +
ggtitle(paste0("Lebanon border on ", Sys.Date())) + theme_light()

ggsave("~/Github/Israel-Hamas/Maps/lebanon_map.jpg", lebanon_map, device="jpg", width=6, height=5, dpi=600)

###West Bank
westbank <- ggmap::get_map(location=c(lon=35.2, lat=31.9), source="google", maptype="roadmap", crop=FALSE, zoom=10)

westbank_map <- ggmap(westbank) +
#geom_point(data=btgs, mapping=aes(x=lon, y=lat, shape=Russian_BTGS), alpha=0.9, colour="purple") +
geom_point(data=firms, mapping=aes(x=lon, y=lat, colour=NASA), alpha=0.5) +
ggtitle(paste0("West Bank on ", Sys.Date())) + theme_light()

ggsave("~/Github/Israel-Hamas/Maps/westbank_map.jpg", westbank_map, device="jpg", width=6, height=5, dpi=600)


###FIRMS Analysis
dates = seq(as.Date("2023-10-07"), Sys.Date(), by="days")

firms_list <- list()
for(i in dates){
  tryCatch(firms_list[[as.character(i)]] <- data.table::fread(paste0("~/GitHub/Israel-Hamas/data/FIRMS/",  as.Date(i, format="%Y-%m-%d", origin="1970-01-01"), ".csv"))[,-1], error=function(e) NULL)
}

new_firms_frame <- as.data.frame(data.table::rbindlist(firms_list, use.names=TRUE, fill=TRUE))
new_firms_frame$acq_date <- as.Date(new_firms_frame$acq_date)

gaza_firms <- new_firms_frame[new_firms_frame$latitude < 31.5 & new_firms_frame$latitude > 31.1 & new_firms_frame$longitude < 34.7 & new_firms_frame$longitude > 34.1,]
gaza_dates = seq(as.Date("2023-10-01"), Sys.Date(), by="days")
gaza_date_firms <- list()
gaza_means_firms <- list()
for(i in gaza_dates){
 gaza_date_firms[[i]] <- gaza_firms[as.Date(gaza_firms$acq_date, format="%Y-%m-%d", origin="1970-01-01") %in% as.Date(i, format="%Y-%m-%d", origin="1970-01-01"),]
 gaza_means_firms[[i]] <- data.frame(Date=as.Date(i, format="%Y-%m-%d", origin="1970-01-01"), FRP=sum(gaza_date_firms[[i]]$frp), Region="Gaza")
}
gaza_firms_summary <- as.data.frame(data.table::rbindlist(gaza_means_firms))

lebanon_dates = seq(as.Date("2023-10-01"), Sys.Date(), by="days")
lebanon_firms <- new_firms_frame[new_firms_frame$latitude < 33.2 & new_firms_frame$latitude > 32.8 & new_firms_frame$longitude < 35.9 & new_firms_frame$longitude > 34.9,]
lebanon_date_firms <- list()
lebanon_means_firms <- list()
for(i in lebanon_dates){
  lebanon_date_firms[[i]] <- lebanon_firms[as.Date(lebanon_firms$acq_date, format="%Y-%m-%d", origin="1970-01-01") %in% as.Date(i, format="%Y-%m-%d", origin="1970-01-01"),]
  lebanon_means_firms[[i]] <- data.frame(Date=as.Date(i, format="%Y-%m-%d", origin="1970-01-01"), FRP=sum(lebanon_date_firms[[i]]$frp), Region="North Donbas")
}
lebanon_firms_summary <- as.data.frame(data.table::rbindlist(lebanon_means_firms))

west_bank_dates = seq(as.Date("2023-10-01"), Sys.Date(), by="days")
west_bank_firms <- new_firms_frame[new_firms_frame$latitude < 31.6 & new_firms_frame$latitude > 32 & new_firms_frame$longitude < 35.6 & new_firms_frame$longitude > 34.7,]
west_bank_date_firms <- list()
west_bank_means_firms <- list()
for(i in west_bank_dates){
    west_bank_date_firms[[i]] <- west_bank_firms[as.Date(west_bank_firms$acq_date, format="%Y-%m-%d", origin="1970-01-01") %in% as.Date(i, format="%Y-%m-%d", origin="1970-01-01"),]
  west_bank_means_firms[[i]] <- data.frame(Date=as.Date(i, format="%Y-%m-%d", origin="1970-01-01"), FRP=sum(west_bank_date_firms[[i]]$frp), Region="South Donbas")
}
west_bank_firms_summary <- as.data.frame(data.table::rbindlist(west_bank_means_firms))

axis_firms_summary <- as.data.frame(data.table::rbindlist(list(gaza_firms_summary, lebanon_firms_summary, west_bank_firms_summary)))

axis_firms_summary_plot <- ggplot(axis_firms_summary, aes(Date, FRP, colour=Region)) +
  #geom_point() +
  geom_line() +
  #stat_smooth(method="gam") +
  scale_x_date(date_labels = "%Y/%m/%d") +
  scale_y_continuous("Total Fire Radiative Power (MegaWatts)", breaks=scales::pretty_breaks(n=10), labels=scales::comma) +
  ggtitle("FIRMS VIIRS I-Band 375 m Active Fire") +
  facet_wrap(.~Region, ncol=1) +
  theme_light() +
  theme(legend.position = "none")

ggsave("~/Github/Israel-Hamas/Plots/region_firms_summary_plot.jpg", axis_firms_summary_plot, device="jpg", width=6, height=6, dpi=600)
