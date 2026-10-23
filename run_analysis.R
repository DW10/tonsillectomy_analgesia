# Stage 2 (analysis, research TRE): turns the anonymised dataset into everything the render
# stage needs. Run from the repo root:
#
#   Rscript run_analysis.R
#
# Reads   data/anon_dataset.rds, data/anon_opioid_sensititvity_df.rds, data/anon_readmit_sensititvity_df.rds
#         (produced by stage 1 and moved here), and scripts/settings.R.
# Writes  export/   summary results only: gt tables, plots, quoted numbers, package citations.
#         data/models.rds   fitted models (they contain patient-level rows, so they stay in data/).
# Then copy export/ to the render machine and run `quarto render` (stage 3, see pre_render.R).

library(here)
setwd(here())
source("scripts/slim_export.R")

anon_files <- file.path("data", c("anon_dataset.rds", "anon_opioid_sensititvity_df.rds", "anon_readmit_sensititvity_df.rds"))
missing <- anon_files[!file.exists(anon_files)]
if (length(missing) > 0) {
  stop("Missing anonymised data: ", paste(missing, collapse = ", "),
       "\nCopy the stage 1 outputs into data/ first.", call. = FALSE)
}
dir.create("export", showWarnings = FALSE)

# knit() swallows chunk errors by default (error = TRUE); stop at the first one instead
knitr::opts_chunk$set(error = FALSE)

# Order matters: the supplementary script reads data/models.rds written by the analysis script
for (script in c("scripts/peri_op_med_analysis.qmd", "scripts/peri_op_med_supp_mat.qmd")) {
  message("Running ", script)
  knitr::knit(script, output = tempfile(fileext = ".md"), quiet = TRUE, envir = new.env())
}

# Numbers quoted inline in the prose: evaluated here so the render stage needs no patient data
message("Saving inline values")
options(inline.record = TRUE)
source("scripts/inline_helpers.R")
write_inline_values()

# R package table + citations for the supplementary materials (grateful); non-fatal if missing
source("scripts/package_citations.R")
write_package_citations()

# ---- check export/ holds results only ------------------------------------------------------
# Saved ggplot objects carry the data frame they were built from. List any that hold many rows
# so you can confirm the content is a summary before export/ leaves the TRE.
embedded_rows <- function(x, depth = 0) {
  if (depth > 6) return(0L)
  if (is.data.frame(x)) return(nrow(x))
  kids <- if (inherits(x, "ggplot")) c(list(x$data), lapply(x$layers, function(l) l$data)) else if (is.list(x)) unclass(x)
  if (length(kids) == 0) return(0L)
  max(0L, vapply(kids, embedded_rows, integer(1), depth = depth + 1))
}
audit_export <- function(threshold = 100L) {
  flagged <- character(0)
  for (f in list.files("export", pattern = "[.]rds$", full.names = TRUE)) {
    obj <- readRDS(f)
    if (!is.list(obj)) next
    for (nm in names(obj)) {
      if (inherits(obj[[nm]], "gt_tbl")) next   # gt tables hold the displayed summary
      n <- embedded_rows(obj[[nm]])
      if (n > threshold) flagged <- c(flagged, sprintf("%s$%s (%d rows)", basename(f), nm, n))
    }
  }
  if (length(flagged) > 0) {
    warning("These saved objects embed data frames with more than 100 rows. Check they contain ",
            "summaries, not patient-level rows, before export/ leaves the TRE:\n  ",
            paste(flagged, collapse = "\n  "), call. = FALSE)
  } else {
    message("export/ check: no saved plot embeds a large data frame")
  }
}
audit_export()

# The .rds files must fit the 10 MB airlock limit: list their sizes, and warn about any single
# object that still carries more than the plot itself (e.g. the analysis session)
rds_files <- list.files("export", pattern = "[.]rds$", full.names = TRUE)
print(data.frame(file = basename(rds_files), MB = round(file.size(rds_files) / 1e6, 2)))
sizes <- report_object_sizes(rds_files)
if (sum(file.size(rds_files)) > 9e6) warning("export/*.rds total ", round(sum(file.size(rds_files)) / 1e6, 1), " MB; zip may exceed 10 MB", call. = FALSE)

message("\nDone. Copy the export/ folder to the render machine, then run `quarto render`.")
