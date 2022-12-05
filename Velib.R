#import the libraries

my_packages <- c("readr",
                 "tidyr",
                 "tibble",
                 "dplyr",
                 "mice",
                 "stringr",
                 "ggplot2",
                 "rvest",
                 "RSelenium",
                 "netstat",
                 "data.table",
                 "httr",
                 "jsonlite",
                 "scales",
                 "ggrepel",
                 "RSQLite")

#check if packages are not installed internally

not_installed <- my_packages[!(my_packages %in% installed.packages()[ , "Package"])]    # Extract not installed packages
if(length(not_installed)) install.packages(not_installed)                               # Install not installed packages


#read the libraries all in once 

lapply(my_packages, require, character.only = TRUE)

# Create our SQLite database
conn <- dbConnect(RSQLite::SQLite(), "Velib_DB.db")

# calling the station_stats API

url <- "https://velib-metropole-opendata.smoove.pro/opendata/Velib_Metropole/station_status.json"

raw_data <- GET(url)

data <- fromJSON(rawToChar(raw_data$content), flatten = TRUE)


# calling the station_information API

url1 <- "https://velib-metropole-opendata.smoove.pro/opendata/Velib_Metropole/station_information.json"

raw_data1 <- GET(url1)

data1 <- fromJSON(rawToChar(raw_data1$content), flatten = TRUE)


# unlist the data from the position api 

df <- data$data %>%
  .$stations

# write.csv(df, file = "~/Perso/perso/station_position.csv")

# station_position <- read.csv("~/Perso/perso/station_position.csv")

# df <- cbind(df,station_position)

# unlist the dat from the information api

df1 <- data1$data %>%
  .$stations

# write.csv(df1, file = "~/Perso/perso/station_information.csv")

# station_information <- read.csv("~/Perso/perso/station_information.csv")

# df1 <- cbind(df,station_information)

# convert the timestamp of the last reported 

#unlist the bikes available per station


mechanical <- data.frame(matrix(nrow = length(df$num_bikes_available_types), ncol = 2))


ebike <- data.frame(matrix(nrow = length(df$num_bikes_available_types), ncol = 2))


for (i in 1:length(df$num_bikes_available_types)) {
  
  mechanical[i,] <- df$num_bikes_available_types[[i]] %>%
    .[[1]]
  
  ebike[i,] <- df$num_bikes_available_types[[i]] %>%
    .[[2]]
}


bike <- cbind(mechanical$X1,ebike$X2) %>%
  data.frame()

colnames(bike) <- c("mechanical","ebike")

df <- df %>%
  subset() %>%
  select(-c(num_bikes_available_types)) %>%
  add_column(bike, .before = 4)

df <- df %>%
  inner_join(df1, by = c("station_id","stationCode"))

# unlist the list of rental_methods 

rental_methods <- df$rental_methods

length(df$rental_methods)

for (i in 1:length(df$rental_methods)) {
  
  
  if (df$rental_methods[i] == "NULL") {
    
    df$rental_methods[i] <- "NA"
    
  } 
  
}

df$rental_methods <- df$rental_methods %>%
  unlist

df$last_reported <- as.POSIXct(df$last_reported, origin ="1970-01-01")

df <- df %>%
  mutate(export_date = Sys.Date()) #put an hour timeframe for analysing over the day

velib <- read.csv(file = "/Users/guilhemjolly/velib.csv")

velib <- rbind(df,velib)
  
write.csv(velib,file = "/Users/guilhemjolly/velib.csv", row.names = FALSE)

dbWriteTable(conn, "Velib_Data", velib, append = T)
