# Stage 3 (render): runs automatically before every full `quarto render` (see `project:
# pre-render` in _quarto.yml), or by hand with `Rscript pre_render.R`. It needs no patient-level
# data, only the products of the analysis stage in export/ (see run_analysis.R).
#
# 0. Only if REFRESH_AUTHORS=true: refreshes the author/affiliation YAML from the plume Google
#    sheet (non-fatal; see scripts/plume_authors.R). Off by default.
# 0a. Only if REFRESH_DIAGRAMS=true: re-renders the Mermaid diagrams (diagrams/*.mmd -> figures/*.png)
#    with scripts/render_diagrams.sh (needs node/npx; non-fatal). Off by default.
# 0b. Regenerates submission/xref-map.yml from the supplementary headings.
# 1. Clears the generated figure/table dump in export/figures and export/tables so it matches
#    this render.
# 2. Checks the analysis products exist in export/ and stops with a clear message if not.

source("scripts/plume_authors.R")
refresh_authors()

# Mermaid diagrams (diagrams/*.mmd -> figures/*.png); opt-in, needs node/npx and headless Chrome
if (identical(tolower(Sys.getenv("REFRESH_DIAGRAMS")), "true")) {
  message("Re-rendering Mermaid diagrams")
  status <- tryCatch(system2("bash", "scripts/render_diagrams.sh"), error = function(e) 1L)
  if (!identical(status, 0L)) warning("Diagram refresh failed, keeping existing figures/*.png", call. = FALSE)
}

# Section numbers used by the submission documents for @sec-sm-* references
source("scripts/xref_map.R")
write_xref_map()

needed <- c(
  "main_objects.rds", "supp_objects_analysis.rds", "supp_objects_extra.rds", "supp_stats.rds",
  "inline_values.rds", file.path("packages", c("packages.csv", "grateful-refs.bib")),
  "upset_adult.png", "upset_paed.png"
)
missing <- needed[!file.exists(file.path("export", needed))]
if (length(missing) > 0) {
  stop(
    "Analysis products missing in export/: ", paste(missing, collapse = ", "),
    "\nRun `Rscript run_analysis.R` in the research TRE (needs the anonymised dataset in data/), ",
    "then copy the export/ folder to this machine.",
    call. = FALSE
  )
}

# The generated dump is rebuilt by show_float() in the book chunks
for (d in c("export/figures", "export/tables")) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  unlink(list.files(d, full.names = TRUE))
}
