#' Modeling of indicator trends
#'
#' The function models the long-term trend of each indicator (IND) based on
#' Generalized Additive Models (GAM) and returns a tibble with
#' IND-specific GAM outputs.
#'
#' @param ind_tbl A data frame, matrix or tibble containing only the (numeric) IND
#'  variables. Single indicators should be coerced into a data frame to keep the
#'  indicator name. If kept as vector, default name will be `ind`.
#' @param time A vector containing the actual time steps (e.g. years; should be the same
#'  for the IND data).
#' @param train The proportion of observations that should go into the training data
#'  on which the GAMs are fitted. Has to be a numeric value between 0 and 1; the default
#'  is 1 (i.e. the full time series is fitted).
#' @param random logical; should the observations for the training data be randomly
#'  chosen? Default is FALSE.
#' @param k Choice of knots (for the smoothing function \code{\link{s}}); the
#'  default is 4.
#' @param family A description of the error distribution and link to be used in the GAM.
#'  This needs to be defined as a family function (see also \code{\link{family}}). All
#'  standard family functions can be used as well some of the distribution families in
#'  the mgcv package (see \code{\link[mgcv]{family.mgcv}}; e.g.\code{\link[mgcv]{negbin}}
#'  or \code{\link[mgcv]{nb}}).
#'
#'
#' @details
#' To test for linear or non-linear long-term changes, each indicator (IND)
#' in the ind_tbl is modeled as a smoothing function of the time vector
#' (usually years) using the \code{\link[mgcv]{gam}} function. The trend can
#' be tested for the full time series (i.e. all observations are used as
#' training data) or for a random or selected subset.
#'
#' The GAMs are build using the default settings in the \code{gam} function and
#' the smooth term function \code{\link[mgcv]{s}}).  However, the user can adjust
#' the distribution and link by modifying the family argument as well as the
#' maximum level of non-linearity by setting the number of knots:
#'
#' \code{gam(ind ~ s(time, k = k), family = family, data = training_data)}
#'
#' @return
#' The function returns a \code{\link[tibble]{tibble}}, which is a trimmed down version of
#' the data.frame(), including the following elements:
#' \describe{
#'   \item{\code{ind_id}}{Indicator IDs.}
#'   \item{\code{ind}}{Indicator names. These might be modified to exclude any character, which
#'               is not in the model formula (e.g. hyphens, brackets, etc. are replaced by an
#'               underscore, variables starting with a number will get an x before the number.}
#'   \item{\code{p_val}}{The p values for the smoothing term (here time).}
#'   \item{\code{model}}{A list-column of indicator-specific gam objects.}
#'   \item{\code{ind_train}}{A list-column with indicator values of the training data.}
#'   \item{\code{time_train}}{A list-column with the time values (e.g. years) of the
#'              training data.}
#'   \item{\code{pred}}{A list-column with indicator values predicted from the GAM
#'              for the training period.}
#'   \item{\code{ci_up}}{A list-column with the upper 95\% confidence interval of
#'              predicted indicator values.}
#'   \item{\code{ci_low}}{A list-column with the lower 95\% confidence interval of
#'              predicted indicator values.}
#' }
#'
#' @seealso \code{\link{plot_diagnostics}} for assessing model diagnostics,
#'  \code{\link{plot_trend}} for trend visualization,
#'  \code{\link[tibble]{tibble}} and the \code{vignette("tibble")} for more
#'  information on tibbles,
#'  \code{\link[mgcv]{gam}} for more information on GAMs
#'
#' @export
#'
#' @examples
#' # Using the Baltic Sea demo data in this package
#' ind_tbl <- ind_ex[ ,-1] # excluding the year
#' time <- ind_ex$Year
#' # Using the default settings
#' trend_tbl <- model_trend(ind_tbl, time)
#' # Change the training and test data assignment
#' model_trend(ind_tbl, time, train = .5, random = TRUE)
#' # To keep the name when testing only one indicator, coerce vector to data frame
#' model_trend(data.frame(MS = ind_tbl$MS), time, train = .5, random = TRUE)
model_trend <- function(ind_tbl, time, train = 1, random = FALSE,
  k = 4, family = stats::gaussian()) {

  # Data input validation -----------------------
  if (missing(ind_tbl)) {
    stop("Argument ind_tbl is missing.")
  }
  if (missing(time)) {
    stop("Argument time is missing.")
  }
  # Check parameters
  y_ <- check_ind_press(ind_tbl)
  time_ <- check_input_vec(time, "time")
  # equal length?
  if (nrow(y_) != length(time_)) {
    stop("The number of time steps in time and ind_tbl have to be the same (i.e. the\tlength of the time vector and length or row number in ind_tbl differ)")
  }

  if (train < 0 | train > 1) {
    stop("The train argument has to be between 0 and 1 (all observations in time)!")
  }

  # Check family class
  if (!"family" %in% class(family)) {
    stop("The specified family is not a family object. You need to provide the family function, e.g. family = poisson()")
  }
  # ----------------

  # Define time units to be included in the model
  nr_train <- round(length(time_) * train)
  if (random) {
    select_train <- sort(sample(1:length(time_),
      size = nr_train, replace = FALSE))
  } else {
    select_train <- 1:nr_train
  }
  select_test <- c(1:length(time))[-select_train]

  # Helper function to name values (needed several
  # times)
  name_values <- function(x, y) {
    names(x) <- y
    return(x)
  }

  # Create dataset with list-columns including only
  # training observations
  trend_tab <- tibble::tibble(ind_id = 1:ncol(y_),
    ind = names(y_))

  # Add train and test data to output and name it by
  # the time vector
  ind_train <- purrr::map(trend_tab$ind, ~y_[select_train,
    .])
  time_train <- purrr::map(trend_tab$ind, ~time_[select_train])
  time_test <- purrr::map(trend_tab$ind, ~time_[select_test])
  # Save only 2 in output tibble
  trend_tab$ind_train <- purrr::map2(ind_train, time_train,
    ~name_values(.x, .y))
  trend_tab$time_train <- time_train

  # Add a logical vector of NA presences in ind_train
  # (incl. NAs in the original data AND of the test
  # data if random = TRUE)
  if (random == FALSE) {
    train_na <- purrr::map(trend_tab$ind, ~is.na(y_[select_train,
      .]))
    trend_tab$train_na <- purrr::map2(train_na,
      time_train, ~name_values(.x, .y))
  } else {
    train_na <- purrr::map(trend_tab$ind, ~is.na(y_[select_train,
      .]))
    train_na <- purrr::map2(train_na, time_train,
      ~name_values(.x, .y))
    # All test observations within the training period
    # will be considered as NAs (so TRUE):
    ind_test_na <- purrr::map(trend_tab$ind, ~rep(TRUE,
      length(select_test)))
    ind_test_na <- purrr::map2(ind_test_na, time_test,
      ~name_values(.x, .y))
    ind_test_na_sub <- seq_along(ind_test_na) %>%
      purrr::map(~ind_test_na[[.]][time_test[[.]] %in%
        min(time_train[[.]]):max(time_train[[.]])])
    # Merge test into train
    sorted_years <- order(as.numeric(c(names(train_na[[1]]),
      names(ind_test_na_sub[[1]]))))
    # (as selected years are for all the same I get the
    # sorted years from the first list)
    train_na <- seq_along(train_na) %>% purrr::map(~c(train_na[[.]],
      ind_test_na_sub[[.]])[sorted_years])
  }

  # Compute the trend GAMs using this helper
  # function:
  apply_gam <- function(ind_name, ind_ts, time_ts,
    train_na_ts, k, family) {
    dat <- data.frame(ind_ts, time = time_ts)
    names(dat)[1] <- ind_name
    model <- mgcv::gam(stats::as.formula(paste0(ind_name,
      " ~ 1 + s(time, k = ", k, ")")), na.action = "na.omit",
      family = family, data = dat)
    # Save train_na in model
    model$train_na <- train_na_ts
    return(model)
  }
  apply_gam_safe <- purrr::safely(apply_gam, otherwise = NA)

  temp_mod <- suppressWarnings(purrr::pmap(.l = list(ind_name = trend_tab$ind,
    ind_ts = trend_tab$ind_train, time_ts = trend_tab$time_train,
    train_na_ts = train_na), .f = apply_gam_safe,
    k = k, family = family)) %>% purrr::transpose()
  trend_tab$model <- temp_mod$result

  if (all(is.na(temp_mod$result))) {
    stop("No indicator trend model could be fitted! Check if you chose the correct error distribution (default is gaussian()).")
  } else {
    # Get p-values
    gam_smy <- suppressWarnings(trend_tab$model %>%
      purrr::map(.f = purrr::possibly(mgcv::summary.gam,
        NA_real_)))
    trend_tab$p_val <- get_sum_output(gam_smy,
      "s.table", 4)
    # Calculate pred +/- CI using another help function
    temp_pred <- calc_pred(trend_tab$model, obs_press = trend_tab$time_train)
    trend_tab <- dplyr::bind_cols(trend_tab, temp_pred)
    # Generate final output tibble
    trend_tab <- trend_tab[ ,c("ind_id", "ind", "p_val",
      "model", "ind_train", "time_train", "pred",
      "ci_up", "ci_low")]
  }

  # Warning if some models were not fitted
  if (any(!purrr::map_lgl(temp_mod$error, .f = is.null))) {
    sel <- !purrr::map_lgl(temp_mod$error, .f = is.null)
    miss_mod <- trend_tab[sel, 1:2]
    miss_mod$error_message <- purrr::map(temp_mod$error,
      .f = as.character) %>% purrr::flatten_chr()
    message("For the following indicators fitting procedure failed:")
    print(miss_mod, n = Inf)
  }

  ### END OF FUNCTION
  return(trend_tab)
}
