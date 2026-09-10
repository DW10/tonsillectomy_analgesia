
library(googledrive)
drive_auth(email = "dylanwhitaker10@gmail.com")
googlesheets4::gs4_auth(token = drive_token())

library(plume)
options(googlesheets4_quiet = TRUE)
tbl_authors <- googlesheets4::read_sheet("123JiCxSHvA7Wiaz6tU25B7Wq27Ty_cV7n6UUqlhyvrY",sheet = 3)
aut <- PlumeQuarto$new(tbl_authors, file="_quarto.yml")
aut$set_corresponding_authors(1)
aut$to_yaml()

