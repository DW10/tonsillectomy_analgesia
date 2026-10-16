# Writes the R package citations for the supplementary materials (section "Analysis code"):
#
#   export/packages/grateful-refs.bib   BibTeX for R and every package the project's code uses
#   export/packages/packages.csv        Package, Version and citation key, read by supplementary_materials.qmd
#
# The packages are found with renv::dependencies() over the analysis scripts and the book
# chapters, then cited with the grateful package (https://pakillo.github.io/grateful/), which
# reads the installed versions and citation() data. Run by run_analysis.R (stage 2).
# Only packages that are installed are listed, so run this where the analysis runs (the TRE or
# Docker image) and copy export/ to the render machine. If grateful or renv is missing it warns and leaves
# the committed files alone, so the book still renders.
#
# Citations stay out of the main reference list in the submission profile: only the
# supplement document lists export/packages/grateful-refs.bib as a bibliography.

write_package_citations <- function(out_dir = file.path("export", "packages")) {
  if (!requireNamespace("grateful", quietly = TRUE) || !requireNamespace("renv", quietly = TRUE)) {
    warning("Package citations not refreshed: install the grateful package (and renv).", call. = FALSE)
    return(invisible(FALSE))
  }
  tryCatch({
    files <- c(
      list.files("scripts", pattern = "[.](qmd|R)$", full.names = TRUE),
      c("abstract.qmd", "manuscript.qmd", "supplementary_tables_and_figures.qmd", "supplementary_materials.qmd")
    )
    # not analysis code: author refresh, settings examples, this tooling
    files <- files[!grepl("plume|settings|package_citations|xref_map", files)]
    used <- sort(unique(renv::dependencies(files, progress = FALSE)$Package))

    dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
    tbl <- suppressWarnings(grateful::cite_packages(
      pkgs = c("base", used), output = "table", out.dir = out_dir,
      bib.file = "grateful-refs", skip.missing = TRUE,
      omit = c("grateful", "renv")
    ))
    keys <- vapply(tbl$Citation, function(k) paste0("[", paste(k, collapse = "; "), "]"), character(1))
    out <- data.frame(Package = tbl$Package, Version = tbl$Version, Citation = keys)
    out <- out[order(tolower(out$Package)), ]
    utils::write.csv(out, file.path(out_dir, "packages.csv"), row.names = FALSE)
    message("Package citations written to ", out_dir, " (", nrow(out), " entries)")
    invisible(TRUE)
  }, error = function(e) {
    warning("Package citations not refreshed: ", conditionMessage(e), call. = FALSE)
    invisible(FALSE)
  })
}
