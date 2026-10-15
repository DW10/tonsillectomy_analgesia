# Runs after `quarto render --profile submission` (see `project: post-render`).
#
# 1. Moves the Word files up out of _submission/submission/ so _submission/ holds
#    cover-letter.docx, manuscript.docx, figures-tables.docx and supplement.docx.
# 2. Builds _submission/figures/: every figure at journal quality (300 dpi PNG and vector PDF
#    written by show_float() into export/figures/, plus the hand-made PNGs in figures/),
#    named Figure_1, Figure_S1, ... in the order the figures appear in the documents.

out_dir <- Sys.getenv("QUARTO_PROJECT_OUTPUT_DIR", "_submission")

# ---- 1. flatten ---------------------------------------------------------------------------
nested <- file.path(out_dir, "submission")
if (dir.exists(nested)) {
  for (f in list.files(nested, pattern = "\\.docx$", full.names = TRUE)) {
    file.rename(f, file.path(out_dir, basename(f)))
  }
  unlink(nested, recursive = TRUE)
}

# ---- 2. figures ---------------------------------------------------------------------------
# Figure labels in document order: main figures from manuscript.qmd, supplementary figures
# from the two supplementary chapters (same order as figures-tables.docx). A label is either
# a chunk option (`#| label: fig-x`, `#| label: chunk-sfig-x`) or a Div/image id (`{#sfig-x}`).
labels_in <- function(path) {
  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")
  m <- gregexpr("(label: (chunk-)?|\\{#)s?fig-[A-Za-z0-9-]+", txt)
  hits <- regmatches(txt, m)[[1]]
  unique(sub("^(label: (chunk-)?|\\{#)", "", hits))
}
main_labels <- grep("^fig-", labels_in("manuscript.qmd"), value = TRUE)
supp_labels <- unique(grep("^sfig-", c(labels_in("supplementary_tables_and_figures.qmd"),
                                       labels_in("supplementary_materials.qmd")), value = TRUE))

fig_dir <- file.path(out_dir, "figures")
unlink(fig_dir, recursive = TRUE)
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

copy_figure <- function(label, name) {
  copied <- character(0)
  for (ext in c("png", "pdf")) {
    for (dir in c("export/figures", "figures")) {
      src <- file.path(dir, paste0(label, ".", ext))
      if (file.exists(src)) {
        file.copy(src, file.path(fig_dir, paste0(name, ".", ext)), overwrite = TRUE)
        copied <- c(copied, paste0(name, ".", ext))
        break
      }
    }
  }
  if (length(copied) == 0) warning("No saved image found for ", label, call. = FALSE)
  copied
}

index <- character(0)
for (i in seq_along(main_labels)) {
  copy_figure(main_labels[i], paste0("Figure_", i))
  index <- c(index, sprintf("Figure_%d = %s", i, main_labels[i]))
}
for (i in seq_along(supp_labels)) {
  copy_figure(supp_labels[i], paste0("Figure_S", i))
  index <- c(index, sprintf("Figure_S%d = %s", i, supp_labels[i]))
}
writeLines(c("# Journal figure name = source label (export/figures/<label>.png|pdf)", index),
           file.path(fig_dir, "figure_index.txt"))
message("Submission figures written to ", fig_dir, " (", length(index), " figures)")
