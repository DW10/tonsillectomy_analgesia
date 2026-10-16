# Helpers for inline results (`r ...`) in index.qmd, abstract.qmd and manuscript.qmd.
#
# Sourced from the setup chunk of each chapter (chapters are knit in separate R sessions).
# Defines short formatters so inline code in the prose stays readable:
#
#   N(x)            count of TRUE / 1 in x            "1,158"
#   P(x, denom)     % of TRUE / 1 (denom default length(x))   "82.9%"
#   med(x, d) q1(x, d) q3(x, d)   median / quartiles to d decimals
#   or_est/or_lo/or_hi(i, term)   odds ratio and CI of model i      (3 significant figures)
#   beta(i, term, part, d, flip)  linear model estimate / CI (model 3)
#   re_var(i) re_sd(i)            random-effect variance (%) and SD (%) of model i
#   study_start() study_end()     first / last date in the dataset
#
# Example:  `r P(adults$simple_analgesia_given)` (n = `r N(adults$simple_analgesia_given)`)
#
# Two modes, so the render stage never needs patient-level data:
#   analysis mode (stage 2, research TRE): loads data/anon_dataset.rds and data/models.rds, and
#     write_inline_values() (called by run_analysis.R) evaluates every inline expression in
#     the chapters and saves the results to export/inline_values.rds.
#   render mode (stage 3, once export/inline_values.rds exists): the dataset and models are
#     NOT loaded. Each formatter below returns the saved value for the exact call written in
#     the prose (the arguments are never evaluated), so the prose can stay unchanged.
# If you edit an inline expression, re-run run_analysis.R so its value is saved.

suppressPackageStartupMessages(library(here))

inline_file <- here("export", "inline_values.rds")
inline_render_mode <- !isTRUE(getOption("inline.record")) && file.exists(inline_file)

comma   <- scales::comma
percent <- scales::percent
ordinal <- scales::label_ordinal()

# ---- data (analysis mode only) --------------------------------------------------------------
if (!inline_render_mode) {
  suppressPackageStartupMessages({
    library(dplyr)
    library(lubridate)
    library(lme4)
  })
  if (!file.exists(here("data", "anon_dataset.rds"))) {
    stop("data/anon_dataset.rds not found and export/inline_values.rds has not been created. ",
         "Run run_analysis.R in the research TRE first.", call. = FALSE)
  }
  df     <- readRDS(here("data", "anon_dataset.rds"))
  adults <- df %>% filter(adult == 1)
  paeds  <- df %>% filter(adult == 0)

  # Treatment groups (1 = simple analgesia, 2 = + morphine, 3 = + fentanyl, 4 = + both)
  adult_group <- lapply(1:4, function(a) adults %>% filter(treatment_arm == a))
  paed_group  <- lapply(1:4, function(a) paeds  %>% filter(treatment_arm == a))

  # models (data/models.rds, written by scripts/peri_op_med_analysis.qmd; it holds the fitted
  # models, which contain patient-level rows, so it stays in data/ and never goes to export/).
  # models[[1]] is model 0 (unadjusted glm); models[[i + 1]] is model i.
  # fe[[i]] is the tidy fixed-effects table of model i (i = 1..6).
  model_save <- readRDS(here("data", "models.rds"))
  models <- model_save[[1]]
  fe     <- model_save[[2]]
  mod    <- function(i) models[[i + 1]]
}

# ---- formatters -----------------------------------------------------------------------------
n_true <- function(x) sum(x == TRUE, na.rm = TRUE)
N <- function(x) comma(n_true(x))
P <- function(x, denom = length(x), acc = 0.1) percent(n_true(x) / denom, acc)

fmt <- function(x, d = 1) formatC(x, format = "f", digits = d)
med <- function(x, d = 1) fmt(median(x, na.rm = TRUE), d)
q1  <- function(x, d = 1) fmt(quantile(x, 0.25, na.rm = TRUE, names = FALSE), d)
q3  <- function(x, d = 1) fmt(quantile(x, 0.75, na.rm = TRUE, names = FALSE), d)

fe_row <- function(i, term) fe[[i]][fe[[i]]$term == term, ]
sf <- function(x, d = 3) format(signif(x, d), trim = TRUE)

or_est <- function(i, term) sf(fe_row(i, term)$odds_ratio)
or_lo  <- function(i, term) sf(fe_row(i, term)$or_lower)
or_hi  <- function(i, term) sf(fe_row(i, term)$or_upper)

# Linear model (model 3, minutes). flip = TRUE reports a reduction as a positive number
# (the CI limits swap).
beta <- function(i, term, part = "estimate", d = 1, flip = FALSE) {
  v <- fe_row(i, term)[[part]]
  if (flip) v <- -v
  fmt(v, d)
}

# Probability of the outcome in the reference group (logistic models)
ref_prob <- function(i) percent(plogis(fe_row(i, "(Intercept)")$estimate), 0.1)

# Random effect of anaesthetist: variance (%) and standard deviation (%)
re <- function(i) as.data.frame(VarCorr(mod(i)))
re_var <- function(i) percent(re(i)$vcov[1], 0.1)
re_sd  <- function(i) percent(re(i)$sdcor[1], 1)

# Patients in the modelling cohort and per treatment group
model_frame <- function(i) model.frame(mod(i))

# Study period
date_text <- function(d) paste0(ordinal(day(d)), " ", month(d, label = TRUE, abbr = FALSE), ", ", year(d))
study_start <- function() date_text(min(df$Date))
study_end   <- function() date_text(max(df$Date))

# ---- saved inline values --------------------------------------------------------------------
# Key = the call exactly as written in the prose (deparsed), so it matches in both stages.
inline_key <- function(expr) paste(deparse(expr, width.cutoff = 500L), collapse = " ")

# Evaluate every inline `r ...` expression in the chapters (analysis mode) and save the results.
write_inline_values <- function(files = c("index.qmd", "abstract.qmd", "manuscript.qmd"),
                                out = inline_file, env = globalenv()) {
  if (inline_render_mode) stop("write_inline_values() needs analysis mode (set options(inline.record = TRUE)).", call. = FALSE)
  values <- list()
  for (f in files[file.exists(here(files))]) {
    txt <- paste(readLines(here(f), warn = FALSE), collapse = "\n")
    code <- regmatches(txt, gregexpr("`r [^`]+`", txt))[[1]]
    code <- sub("`$", "", sub("^`r +", "", code))
    for (cd in unique(code)) {
      expr <- parse(text = cd)[[1]]
      values[[inline_key(expr)]] <- tryCatch(
        eval(expr, env),
        error = function(e) stop("Inline expression failed in ", f, ": ", cd, "\n", conditionMessage(e), call. = FALSE)
      )
    }
  }
  dir.create(dirname(out), showWarnings = FALSE, recursive = TRUE)
  saveRDS(values, out)
  message("Saved ", length(values), " inline values to ", out)
  invisible(values)
}

# Render mode: return the saved value for this exact call without evaluating its arguments.
if (inline_render_mode) {
  inline_values <- readRDS(inline_file)
  with_saved_value <- function(f, name) {
    force(f); force(name)
    function(...) {
      key <- inline_key(sys.call())
      if (key %in% names(inline_values)) return(inline_values[[key]])
      # comma() / percent() are general formatters: fall back to the real function
      if (name %in% c("comma", "percent")) return(f(...))
      stop("No saved inline value for `", key, "`. Re-run run_analysis.R so export/inline_values.rds ",
           "includes it (the render stage has no patient-level data).", call. = FALSE)
    }
  }
  for (nm in c("N", "P", "med", "q1", "q3", "comma", "percent", "or_est", "or_lo", "or_hi",
               "beta", "re_var", "re_sd", "ref_prob", "study_start", "study_end")) {
    assign(nm, with_saved_value(get(nm), nm))
  }
}
