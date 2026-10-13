# Helpers used by manuscript.qmd and supplementary.qmd to print AND export floats.
#
# Every figure/table in the book is one chunk with a `label` (fig-*, tbl-*, sfig-*,
# stbl-*) and a caption, whose body is just `show_float(<store>)`. show_float():
#   1. looks up the object in the store from the chunk label (`-` -> `_`),
#   2. saves a copy named after the label into export/figures/ or export/tables/
#      (this is the "image and table dump" for journal upload),
#   3. returns the object so knitr prints it in the document as normal.
#
# export/ is wiped at the start of a full render by pre_render.R so it always matches
# the current manuscript.

library(here)

# Load an object list written by the analysis stage. `name` is "main" or "supp"; "supp"
# combines the objects from both supplementary analysis scripts.
load_objects <- function(name) {
  files <- switch(name,
    main = "main_objects.rds",
    supp = c("supp_objects_analysis.rds", "supp_objects_extra.rds"),
    stop("Unknown object store: ", name)
  )
  paths <- here("data", files)
  missing <- paths[!file.exists(paths)]
  if (length(missing) > 0) {
    stop(
      "Missing analysis output: ", paste(basename(missing), collapse = ", "),
      "\nRun the analysis stage first (Rscript pre_render.R, or RUN_ANALYSIS=true quarto render).",
      call. = FALSE
    )
  }
  do.call(c, lapply(paths, readRDS))
}

load_stats <- function() {
  path <- here("data", "supp_stats.rds")
  if (!file.exists(path)) stop("Missing data/supp_stats.rds - run the analysis stage first.", call. = FALSE)
  readRDS(path)
}

# Save + return a labelled float.
#   store   list from load_objects(); the object is `store[[gsub("-", "_", label)]]`
#   width, height, scale, dpi  export size in inches for ggplots (as the old ggsave() calls)
show_float <- function(store, width = 8, height = 5, scale = 1, dpi = 300,
                       label = knitr::opts_current$get("label")) {
  if (is.null(label) || grepl("^unnamed-chunk", label)) {
    stop("show_float() must be called from a chunk with a `label:` option.", call. = FALSE)
  }
  key <- gsub("-", "_", label)
  x <- store[[key]]
  if (is.null(x)) {
    stop("No object named `", key, "` in the store for label `", label, "`.", call. = FALSE)
  }

  fig_dir <- here("export", "figures")
  tbl_dir <- here("export", "tables")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(tbl_dir, recursive = TRUE, showWarnings = FALSE)

  if (inherits(x, "gt_tbl")) {
    gt::gtsave(x, file.path(tbl_dir, paste0(label, ".docx")))
    gt::gtsave(x, file.path(tbl_dir, paste0(label, ".html")))
    # PNG needs the optional webshot2 package + Chrome; skipped silently if unavailable
    try(gt::gtsave(x, file.path(tbl_dir, paste0(label, ".png"))), silent = TRUE)
    return(x)
  }

  if (inherits(x, "ggplot") || inherits(x, "patchwork") || inherits(x, "ggarrange")) {
    for (ext in c("png", "pdf")) {
      ggplot2::ggsave(
        filename = file.path(fig_dir, paste0(label, ".", ext)),
        plot = x, width = width, height = height, scale = scale, dpi = dpi, bg = "white"
      )
    }
    return(x)
  }

  if (is.character(x) && length(x) == 1 && file.exists(here(x))) {
    # An image already on disk (e.g. UpSet PNG): copy it and include it
    file.copy(here(x), file.path(fig_dir, paste0(label, ".", tools::file_ext(x))), overwrite = TRUE)
    return(knitr::include_graphics(here(x)))
  }

  warning("show_float(): don't know how to export an object of class ",
          paste(class(x), collapse = "/"), " (label ", label, ")")
  x
}
