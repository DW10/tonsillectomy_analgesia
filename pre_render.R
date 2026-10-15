# Runs automatically before every full `quarto render` (see `project: pre-render` in
# _quarto.yml), or by hand with `Rscript pre_render.R`.
#
# 0. Refreshes the author/affiliation YAML from the plume Google sheet (non-fatal; see
#    scripts/plume_authors.R).
# 1. Clears the generated figure/table dump in export/ so it matches this render.
# 2. Checks the analysis outputs exist (data/*.rds). If RUN_ANALYSIS=true it first
#    re-runs the analysis scripts - this needs the anonymised dataset, so do it inside
#    the research TRE / Docker container, not on a laptop.
#
#    RUN_ANALYSIS=true quarto render      # recompute everything, then render the book
#    quarto render                        # reuse the saved data/*.rds, just render

source("scripts/plume_authors.R")
refresh_authors()

run_analysis <- identical(tolower(Sys.getenv("RUN_ANALYSIS")), "true")

# The generated dump is rebuilt by show_float() in the book chunks
for (d in c("export/figures", "export/tables")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  unlink(setdiff(list.files(d, full.names = TRUE, all.files = FALSE), file.path(d, ".gitkeep")))
}

if (run_analysis) {
  # Order matters: the supplementary script reads data/models.rds written by the analysis script
  for (script in c("scripts/peri_op_med_analysis.qmd", "scripts/peri_op_med_supp_mat.qmd")) {
    message("Running ", script)
    knitr::knit(script, output = tempfile(fileext = ".md"), quiet = TRUE, envir = new.env())
  }
}

needed <- c("main_objects.rds", "supp_objects_analysis.rds", "supp_objects_extra.rds", "supp_stats.rds")
missing <- needed[!file.exists(file.path("data", needed))]
if (length(missing) > 0) {
  stop(
    "Analysis outputs missing in data/: ", paste(missing, collapse = ", "),
    "\nRun with RUN_ANALYSIS=true (needs the anonymised dataset), or copy these files from the TRE.",
    call. = FALSE
  )
}
