# Keeps the .rds files in export/ small (sourced by run_analysis.R and the analysis scripts).
#
# Why the files were ~7 MB each: the analysis scripts are knit in a throw-away environment
# (new.env()). A ggplot remembers the environment it was created in (`plot$plot_env`, the
# environment of every aes() quosure, ggproto internals), and saveRDS() writes any non-global
# environment out in full. So each plot carried the whole analysis session: the dataset, the
# fitted models and every intermediate table.
#
# The plots are NOT edited (resetting their environments breaks plots whose aesthetics read
# variables from a package function's frame, e.g. ggconsort's `label_height`). Instead the large
# objects are set aside from the session while it is written, so the plots keep every
# environment they need but the environments are small.
#
#   save_slim_rds(x, file, session)   saveRDS() with xz and the session's large objects set aside
#   report_object_sizes(files)        serialised size of each element, to spot anything still large

# `session` is the environment the analysis ran in (pass environment() from a chunk). Its large
# non-function objects are removed for the duration of the call and put back afterwards, so
# nothing is lost; a saved plot never needs them because it carries its own data.
save_slim_rds <- function(x, file, session = parent.frame(), keep_mb = 0.1) {
  force(x)   # evaluate before anything is set aside, in case `x` is built from session objects
  big <- Filter(function(nm) !is.function(get(nm, session)) && object.size(get(nm, session)) > keep_mb * 1e6,
                ls(session, all.names = TRUE))
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
