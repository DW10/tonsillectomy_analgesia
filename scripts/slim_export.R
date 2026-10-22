# Keeps the .rds files in export/ small (sourced by run_analysis.R and the analysis scripts).
#
# Why the files were ~7 MB each: the analysis scripts are knit in a throw-away environment
# (new.env()). A ggplot remembers the environment it was created in (`plot$plot_env`, and the
# environment of every aes() quosure), and saveRDS() writes any non-global environment out in
# full. So each plot carried the whole analysis session: the dataset, the fitted models and every
# intermediate table. Resetting those environments to the global environment keeps the plot
# (its own data and settings) and drops the session.
#
#   slim_plot(p)                 one ggplot / patchwork with its environments reset
#   slim_objects(x)              a (named) list of floats: plots are slimmed, everything else kept
#   save_slim_rds(x, file)       slim_objects() + xz compression (gzip output barely zips again)
#   report_object_sizes(files)   serialised size of each element, to spot anything still large

reset_quosure_envs <- function(x) {
  if (rlang::is_quosure(x)) return(rlang::quo_set_env(x, globalenv()))
  if (is.data.frame(x) || !is.list(x)) return(x)
  # assign in place (not lapply + attributes<-) so classed lists such as ggplot2 4's aes() mapping keep their class
  for (i in seq_along(x)) {
    v <- reset_quosure_envs(x[[i]])
    if (!is.null(v)) x[[i]] <- v
  }
  x
}

slim_plot <- function(p) {
  if (!inherits(p, "ggplot")) return(p)
  p$plot_env <- globalenv()
  p$mapping <- reset_quosure_envs(p$mapping)
  if (!is.null(p$facet$params)) p$facet$params <- reset_quosure_envs(p$facet$params)
  for (i in seq_along(p$layers)) {
    p$layers[[i]]$mapping <- reset_quosure_envs(p$layers[[i]]$mapping)
    p$layers[[i]]$aes_params <- reset_quosure_envs(p$layers[[i]]$aes_params)
  }
  # patchwork stores the sub-plots of a composition in p$patches$plots
  if (!is.null(p$patches$plots)) p$patches$plots <- lapply(p$patches$plots, slim_plot)
  p
}

slim_objects <- function(x) {
  if (inherits(x, "ggplot")) return(slim_plot(x))
  if (is.list(x) && !is.data.frame(x) && !inherits(x, "gt_tbl")) {
    attrs <- attributes(x)
    x <- lapply(x, slim_objects)
    attributes(x) <- attrs
  }
  x
}

# Plots also reach the session through ggproto internals (layers, facets) that cannot be reset
# one by one. So while writing, the large objects in `session` (the environment the analysis ran
# in) are set aside and put back afterwards. Nothing is lost: `session` is only emptied for the
# duration of the call, and a plot never needs the session's objects to be drawn again.
save_slim_rds <- function(x, file, session = parent.frame(), keep_mb = 0.1) {
  x <- slim_objects(x)
  big <- Filter(function(nm) is.environment(session) && !is.function(get(nm, session)) &&
                  object.size(get(nm, session)) > keep_mb * 1e6, ls(session, all.names = TRUE))
  stash <- mget(big, envir = session)
  rm(list = big, envir = session)
  on.exit(list2env(stash, envir = session), add = TRUE)
  saveRDS(x, file, compress = "xz")
  message(sprintf("%s: %.2f MB", basename(file), file.size(file) / 1e6))
  invisible(file)
}

# Serialised size (MB) of every element of each saved list, largest first.
report_object_sizes <- function(files, warn_mb = 5) {
  rows <- do.call(rbind, lapply(files, function(f) {
    obj <- readRDS(f)
    if (!is.list(obj)) return(NULL)
    data.frame(file = basename(f), object = names(obj),
               mb = vapply(obj, function(o) length(serialize(o, NULL)) / 1e6, numeric(1)))
  }))
  if (is.null(rows)) return(invisible(NULL))
  rows <- rows[order(-rows$mb), ]
  big <- rows[rows$mb > warn_mb, ]
  if (nrow(big) > 0) {
    warning("These saved objects are over ", warn_mb, " MB uncompressed; check they do not carry the analysis session:\n  ",
            paste0(big$file, "$", big$object, " (", round(big$mb, 1), " MB)", collapse = "\n  "), call. = FALSE)
  }
  invisible(rows)
}
