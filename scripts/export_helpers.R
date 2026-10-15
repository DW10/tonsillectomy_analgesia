# Helpers used by manuscript.qmd and supplementary_*.qmd to print AND export floats.
#
# Every figure/table in the book is one chunk whose body is just `show_float(<store>)`.
# Main floats (fig-*, tbl-*) are chunks with `label` + `fig-cap`/`tbl-cap`. Supplementary
# floats (sfig-*, stbl-*) are custom cross-reference types, which Quarto only supports on
# a Div: `::: {#sfig-x}` containing a chunk labelled `chunk-sfig-x`, then the caption as the
# last paragraph. show_float():
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

# Drop gt's cell-level styling (fills such as \cellcolor, bold/italic text styles) so Word and
# PDF tables use the native table defaults. Structure (headers, spanners, footnotes) is kept.
plain_gt <- function(x) {
  x[["_styles"]] <- x[["_styles"]][0, ]
  x
}

# Save + return a labelled float.
#   store   list from load_objects(); the object is `store[[gsub("-", "_", label)]]`
#   width, height, scale, dpi  export size in inches for ggplots (as the old ggsave() calls)
show_float <- function(store, width = 8, height = 5, scale = 1, dpi = 300,
                       label = knitr::opts_current$get("label")) {
  if (is.null(label) || grepl("^unnamed-chunk", label)) {
    stop("show_float() must be called from a chunk with a `label:` option.", call. = FALSE)
  }
  # Supplementary floats use the documented Div form for custom cross-reference types:
  # the Div carries the label (#sfig-x / #stbl-x) and the chunk inside is `chunk-<label>`.
  label <- sub("^chunk-", "", label)
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
    # HTML keeps the styled table; PDF and Word (and the exported copies) use native defaults
    if (!knitr::is_html_output()) x <- plain_gt(x)
    gt::gtsave(x, file.path(tbl_dir, paste0(label, ".docx")))
    gt::gtsave(x, file.path(tbl_dir, paste0(label, ".html")))
    # PNG needs the optional webshot2 package + Chrome; skipped silently if unavailable
    try(gt::gtsave(x, file.path(tbl_dir, paste0(label, ".png"))), silent = TRUE)

    if (knitr::is_latex_output()) {
      # gt writes its own \begin{table} float, which LaTeX rejects inside the float Quarto
      # already wraps around tbl-/stbl- chunks ("Not in outer par mode"). Keep the tabular only.
      lx <- gt::as_latex(x)
      # as_latex() attaches the LaTeX packages the table needs (colortbl for \cellcolor,
      # booktabs, multirow, ...). They must be passed on or the preamble lacks them.
      latex_deps <- attr(lx, "knit_meta")
      tex <- as.character(lx)
      tex <- gsub("\\\\begin\\{table\\}(\\[[^]]*\\])?\\s*", "", tex)
      tex <- gsub("\\\\end\\{table\\}", "", tex)
      # \caption* is only valid inside a float: keep any gt title/subtitle as plain text
      tex <- gsub("\\\\caption\\*(\\{(?:[^{}]++|(?1))*\\})(\\s*\\\\\\\\)?", "\\\\noindent\\1\\\\par\\\\smallskip", tex, perl = TRUE)
      return(knitr::asis_output(tex, meta = latex_deps))
    }
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
