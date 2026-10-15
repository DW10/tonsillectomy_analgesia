# Refresh the author / affiliation blocks from the shared plume Google sheet.
#
# Called from pre_render.R before every render. Writes the `author:` and `affiliations:`
# keys of _quarto.yml, the single source of truth: project-level metadata is inherited by
# the book (website profile) and by every submission document. (Project-level
# `metadata-files` is not applied by Quarto, so a separate authors file would need copying.)
# Other keys in the file are left alone.
#
# Never blocks a render: with no network, no Google login or no plume installed it warns and
# keeps the existing YAML. Set SKIP_AUTHOR_REFRESH=true to skip it.

refresh_authors <- function(file = "_quarto.yml",
                            sheet_id = "123JiCxSHvA7Wiaz6tU25B7Wq27Ty_cV7n6UUqlhyvrY",
                            sheet = 3,
                            google_email = "dylanwhitaker10@gmail.com") {
  if (identical(tolower(Sys.getenv("SKIP_AUTHOR_REFRESH")), "true")) {
    message("Author refresh skipped (SKIP_AUTHOR_REFRESH=true)")
    return(invisible(FALSE))
  }
  tryCatch({
    for (pkg in c("plume", "googledrive", "googlesheets4")) {
      if (!requireNamespace(pkg, quietly = TRUE)) stop("package ", pkg, " is not installed")
    }
    options(googlesheets4_quiet = TRUE)
    googledrive::drive_auth(email = google_email)
    googlesheets4::gs4_auth(token = googledrive::drive_token())
    tbl_authors <- googlesheets4::read_sheet(sheet_id, sheet = sheet)

    aut <- plume::PlumeQuarto$new(tbl_authors, file = file)
    aut$set_corresponding_authors(1)
    aut$to_yaml()
    message("Authors updated from plume sheet: ", file)
    invisible(TRUE)
  }, error = function(e) {
    warning("Author refresh failed, keeping existing author YAML: ", conditionMessage(e), call. = FALSE)
    invisible(FALSE)
  })
}
