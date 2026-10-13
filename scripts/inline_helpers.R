# Helpers for inline results (`r ...`) in index.qmd and manuscript.qmd.
#
# Sourced from the setup chunk of each chapter (chapters are knit in separate R sessions).
# Loads the anonymised dataset and the fitted models saved by the analysis stage, and
# defines short formatters so inline code in the prose stays readable:
#
#   N(x)            count of TRUE / 1 in x            "1,158"
#   P(x, denom)     % of TRUE / 1 (denom default length(x))   "82.9%"
#   med(x, d) q1(x, d) q3(x, d)   median / quartiles to d decimals
#   or_est/or_lo/or_hi(i, term)   odds ratio and CI of model i      (3 significant figures)
#   beta(i, term, part, d, flip)  linear model estimate / CI (model 3)
#   re_var(i) re_sd(i)            random-effect variance (%) and SD (%) of model i
#
# Example:  `r P(adults$simple_analgesia_given)` (n = `r N(adults$simple_analgesia_given)`)

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(lme4)
  library(here)
})

comma   <- scales::comma
percent <- scales::percent
ordinal <- scales::label_ordinal()

# ---- data ---------------------------------------------------------------------------------
df     <- readRDS(here("data", "anon_dataset.rds"))
adults <- df %>% filter(adult == 1)
paeds  <- df %>% filter(adult == 0)

# Treatment groups (1 = simple analgesia, 2 = + morphine, 3 = + fentanyl, 4 = + both)
adult_group <- lapply(1:4, function(a) adults %>% filter(treatment_arm == a))
paed_group  <- lapply(1:4, function(a) paeds  %>% filter(treatment_arm == a))

# Opioid strategies (strong opioids: fentanyl and/or morphine)
fent_only <- function(d) d$intra_op_fentanyl_given == 1 & d$intra_op_morphine_sulfate_given == 0
morph_only <- function(d) d$intra_op_fentanyl_given == 0 & d$intra_op_morphine_sulfate_given == 1
both_opioids <- function(d) d$intra_op_fentanyl_given == 1 & d$intra_op_morphine_sulfate_given == 1
no_opioids <- function(d) d$intra_op_fentanyl_given == 0 & d$intra_op_morphine_sulfate_given == 0

# ---- formatters ---------------------------------------------------------------------------
n_true <- function(x) sum(x == TRUE, na.rm = TRUE)
N <- function(x) comma(n_true(x))
P <- function(x, denom = length(x), acc = 0.1) percent(n_true(x) / denom, acc)

fmt <- function(x, d = 1) formatC(x, format = "f", digits = d)
med <- function(x, d = 1) fmt(median(x, na.rm = TRUE), d)
q1  <- function(x, d = 1) fmt(quantile(x, 0.25, na.rm = TRUE, names = FALSE), d)
q3  <- function(x, d = 1) fmt(quantile(x, 0.75, na.rm = TRUE, names = FALSE), d)

# ---- models (data/models.rds, written by scripts/peri_op_med_analysis.qmd) ----------------
# models[[1]] is model 0 (unadjusted glm); models[[i + 1]] is model i.
# fe[[i]] is the tidy fixed-effects table of model i (i = 1..6).
model_save <- readRDS(here("data", "models.rds"))
models <- model_save[[1]]
fe     <- model_save[[2]]
mod    <- function(i) models[[i + 1]]

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
