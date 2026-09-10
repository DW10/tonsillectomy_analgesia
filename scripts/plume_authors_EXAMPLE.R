library(googledrive)
#drive_auth(email = "<youremailhere>@gmail.com")
#googlesheets4::gs4_auth(token = drive_token())

## Then we fetch the updated author list and refresh the .yaml with the updated info

library(plume)
options(googlesheets4_quiet = TRUE)
#tbl_authors <- googlesheets4::read_sheet("<YOURSHEETIDHERE>",sheet = 2)
#aut <- PlumeQuarto$new(tbl_authors, file="_quarto.yml")
#aut$set_corresponding_authors(1)
#aut$to_yaml()