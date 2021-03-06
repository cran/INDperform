#' Summary of indicator performance scores
#'
#' Summarizes the scoring output tibble so that IND-specific scores for each
#' criterion as well as the pressure-specific sub-criteria scores (in crit.
#' 9 and 10) can be easily compared and used for further score-based IND
#' performance functions.
#'
#' @param scores_tbl The output tibble from the \code{\link{scoring}}
#'  function.
#' @param crit_scores The (un)modified criterion-scoring template
#'  \code{crit_scores_tmpl}; required to calculate the scores in
#'  percentage. Has to be the same than used in \code{scoring}. Default
#'  is the unmodified template \code{crit_scores_tmpl}.
#'
#' @return
#' The function returns a list of 3 data frames
#' \describe{
#'   \item{\code{overview}}{IND-specific scores and percentages from
#'         max. score for all criteria (crit 9 and 10 averaged across
#'         all sign. pressures and the number of significant pressures).}
#'   \item{\code{subcriteria_per_press}}{IND- and pressure-specific scores for
#'          all (sub-)criteria and the percentages from max. criterion score.}
#'   \item{\code{scores_matrix}}{TEXT}
#' }
#'
#' @family score-based IND performance functions
#'
#' @export
#'
#' @examples
#' # Using the Baltic Sea demo data in this package
#' scores_tbl <- scoring(trend_tbl = model_trend_ex, mod_tbl = all_results_ex,
#'   press_type = press_type_ex)
#' summary_sc(scores_tbl)
summary_sc <- function(scores_tbl, crit_scores = INDperform::crit_scores_tmpl) {

  # Data input validation -----------------------
  if (missing(scores_tbl)) {
    stop("Argument scores_tbl is missing.")
  }
  # Check input tibble
  scores_tbl <- check_input_tbl(scores_tbl, tbl_name = "scores_tbl",
    parent_func = "scoring()", var_to_check = c("ind"), dt_to_check = c("character"))

  # Data preparation -------------------

  # Get weighted scores for calculating total scores
  crit_scores$weighted_score <- crit_scores$score * crit_scores$weight

  # Get total scores per criterion
  vars <- rlang::syms(c("crit", "subcrit"))
  total_sc <- crit_scores %>%
  	dplyr::group_by(!!!vars) %>%
   dplyr::summarise(max_score = max(!!rlang::sym("score"))) %>%
   dplyr::group_by(!!rlang::sym("crit")) %>%
  	dplyr::summarise(total_score = sum(!!rlang::sym("max_score")))


  # Separate data into general and pressure-specific scores
  # (here only significant pressures) but check first if
  # criteria are present in scoring tibble
  vars <- names(scores_tbl)[names(scores_tbl) %in% c("ind",
    "C8", "C11")]
  if (sum(c("C8", "C11") %in% names(scores_tbl)) > 0) {
    scores_c811 <- scores_tbl[, vars]

    scores_c811_out3 <- scores_c811

    # Add proportions
    for (i in 2:ncol(scores_c811)) {
      crit_s <- names(scores_c811)[i]
      new_var <- paste0(crit_s, "_in%")
      tsc <- total_sc$total_score[total_sc$crit == crit_s]
      scores_c811[, new_var] <- round(scores_c811[, i]/tsc *
        100, 0)
    }

  }

  if ("press_spec_sc" %in% names(scores_tbl) == TRUE) {
    # Extract scores of sign.pressures
    scores_c910 <- scores_tbl %>%
    	dplyr::select(!!!rlang::syms(c("ind","press_spec_sc"))) %>%
    	tidyr::unnest(cols = c(!!!rlang::syms("press_spec_sc")))
    vars <- names(scores_c910)[!names(scores_c910) %in% c("ind",
      "press", "id", "press_type")]
    keep_in <- rowSums(scores_c910[, vars]) > 0
    scores_c910 <- scores_c910[keep_in, ]

    # Make data long for the aggregation in output 1
    vars <- rlang::syms(vars)
    scores_c910_l <- scores_c910 %>%
    	tidyr::gather(key = "subcrit", value = "score", !!!vars)
    # Add the criteria
    scores_c910_l$crit <- sub("\\_.*", "", scores_c910_l$subcrit)
  }

  # Generate Output Table 1 ---------------------------------
  # (Overview table where C9 and C10 are averaged across sign.
  # press)

  ### If only C8 and/or 11 were scored but NOT C9/10:
  if (sum(c("C8", "C11") %in% names(scores_tbl)) > 0 & "press_spec_sc" %in%
    names(scores_tbl) == FALSE) {

    # Returned output
    print_list <- vector("list", length = 1)
    names(print_list)[1] <- "Overview"
    print_list[[1]] <- scores_c811

  } else {

    # Calculate sum across sub-criteria in C9 and C10 and return
    # to wide format (long format simply to avoid if statements
    # for checking for crit presence)
    vars <- rlang::syms(c("ind", "press", "crit"))
    scores_c910_sum <- scores_c910_l %>%
    	 dplyr::group_by(!!!vars) %>%
      dplyr::summarise(sum_score = sum(!!rlang::sym("score"))) %>%
      tidyr::spread(!!rlang::sym("crit"), !!rlang::sym("sum_score"))


    # Calculate number of sign. pressures and mean across
    # sign.pressures for C9/C10
    scores_c910_mean <- scores_c910_sum %>%
    	 dplyr::group_by(!!rlang::sym("ind")) %>%
      dplyr::summarise(
      	nr_sign_press = dplyr::n_distinct(!!rlang::sym("press")),
        C9 = round(sum(!!rlang::sym("C9"))/(!!rlang::sym("nr_sign_press")),
          1),
      	C10 = round(sum(!!rlang::sym("C10"))/(!!rlang::sym("nr_sign_press")),
          1)
      	)


    # Add proportions of total scores
    for (i in 3:ncol(scores_c910_mean)) {
      crit_s <- names(scores_c910_mean)[i]
      new_var <- paste0(crit_s, "_in%")
      tsc <- total_sc$total_score[total_sc$crit == crit_s]
      scores_c910_mean[, new_var] <- round(scores_c910_mean[,
        i]/tsc * 100, 0)
    }


    ### If only C9/10 were scored but NOT C8/11:
    if (sum(c("C8", "C11") %in% names(scores_tbl)) == 0 &
      "press_spec_sc" %in% names(scores_tbl) == TRUE) {

      # return list with scores_c910_mean as first output list
      out1 <- as.data.frame(scores_c910_mean)

    } else {

      ### Combine datasets if both exist
      score_overview <- dplyr::left_join(scores_c811, scores_c910_mean,
        by = "ind")
      score_overview <- score_overview %>%
      	dplyr::select(!!rlang::sym("ind"),
        !!rlang::sym("nr_sign_press"), dplyr::everything())

      # Convert NAs in nr_sign_press, C9, and C10 (due to lack of
      # pressure responses) to zero
      score_overview[is.na(score_overview)] <- 0

      # Order variables
      all_var <- c("ind", "nr_sign_press", unique(crit_scores$crit),
        paste0(unique(crit_scores$crit), "_in%"))
      present_var <- names(score_overview)
      order_var <- all_var[all_var %in% present_var]
      score_overview <- score_overview[, order_var]

      # return sublist
      out1 <- as.data.frame(score_overview)

    }
  }



  # Generate Output Table 2 -------------------------
  # (Pressure-specific scores)

  if ("press_spec_sc" %in% names(scores_tbl) == TRUE) {

    out2 <- scores_c910
    out2$id <- NULL

    ### Merge the total scores across sub-criteria from calculation
    ### in output1, including the proportion

    # Add proportions of total scores
    for (i in 3:ncol(scores_c910_sum)) {
      crit_s <- names(scores_c910_sum)[i]
      new_var <- paste0(crit_s, "_in%")
      tsc <- total_sc$total_score[total_sc$crit == crit_s]
      scores_c910_sum[, new_var] <- round(scores_c910_sum[,
        i]/tsc * 100, 0)
    }

    # Order variables
    order_var <- c("ind", "press", unique(scores_c910_l$crit),
      paste0(unique(scores_c910_l$crit), "_in%"))
    scores_c910_sum <- scores_c910_sum[, order_var]

    out2 <- as.data.frame(dplyr::left_join(out2, scores_c910_sum,
      by = c("ind", "press")))

  }


  # Generate Output Table 3 --------------------- (Matrix of
  # all (pressure-specific) criteria, uncluding all tested
  # pressures)


  if ("press_spec_sc" %in% names(scores_tbl) == TRUE) {

      # Extract scores of sign. pressures
      vars <- rlang::syms(c("ind", "press_spec_sc"))
      scores_c910 <- scores_tbl %>%
      	dplyr::select(!!!vars) %>%
        tidyr::unnest(cols = c(!!!rlang::syms("press_spec_sc")))
      # Make data long for calculating total scores per criterion
      vars <- rlang::syms(names(scores_c910)[!names(scores_c910) %in%
        c("ind", "id", "press", "press_type")])
      scores_c910_l <- scores_c910 %>%
      	tidyr::gather(key = "subcrit", value = "score", !!!vars)
      # Add the criteria
      scores_c910_l$crit <- sub("\\_.*", "", scores_c910_l$subcrit)

      # Calculate sum across sub-criteria in C9 and C10
      vars <- rlang::syms(c("ind", "press", "crit"))
      scores_c910_sum <- scores_c910_l %>%
      	dplyr::group_by(!!!vars) %>%
      	dplyr::summarise(score = sum(!!rlang::sym("score"))) %>%
      	dplyr::ungroup(.)  # needed for later operations


      # Add new variable that identifies pressure and crit
      scores_c910_sum$press_crit <- paste(scores_c910_sum$press,
        scores_c910_sum$crit, sep = "_")

      # Make datasets wide for merging with scores_c811
      vars <- rlang::syms(c("ind", "press_crit", "score"))
      scores_c910w <- scores_c910_sum %>%
      	dplyr::select(!!!vars) %>%
        tidyr::spread(!!rlang::sym("press_crit"), !!rlang::sym("score"))

    }  # end of if statement for C9/10 scores


  # Merging of data depending on criteria included ----

  # If only C8 and/or 11 were scored but NOT C9/10:
  if (sum(c("C8", "C11") %in% names(scores_tbl)) > 0 & "press_spec_sc" %in%
    names(scores_tbl) == FALSE) {

    out3 <- as.data.frame(scores_c811_out3)
    rownames(out3) <- out3$ind
    out3$ind <- NULL

  } else {

    # If only C9/10 were scored but NOT C8/11:
    if (sum(c("C8", "C11") %in% names(scores_tbl)) == 0 &
      "press_spec_sc" %in% names(scores_tbl) == TRUE) {

      out3 <- as.data.frame(scores_c910w)
      rownames(out3) <- out3$ind
      out3$ind <- NULL

    } else {

      # Combine datasets if both exist
      out3 <- as.data.frame(dplyr::left_join(scores_c811_out3,
        scores_c910w, by = "ind"))
      rownames(out3) <- out3$ind
      out3$ind <- NULL

    }
  }


  ### END OF FUNCTION ###

  print_list <- list(out1, out2, out3)
  names(print_list) <- c("overview", "subcriteria_per_press",
    "scores_matrix")

  return(print_list)
}
