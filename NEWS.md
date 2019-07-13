# INDperform 0.2.1

* Fixed a minor issue with different test results under different R versions by modifying some tests.


# INDperform 0.2.0

## Breaking changes

* The `summary_sc()` function has a new 3rd output list, which shows all the pressure-independent scores and the pressure-specific scores for both sensitivity and robustness (i.e. the sum of C9 and C10 sub-criteria) as matrix. This table now serves as bases for some score-based IND performance functions (i.e. `dist_sc()`, `plot_spiechart()`).

* The `dist_sc()` takes now as input the new sub`$scores_matrix` from the `summary_sc()` function (instead of the output tibble from the `scoring()` function).

## Major changes

* NRMSE computation in `model_gam()` and `model_gamm()` is now based on the standard deviation instead of the mean as before. This has consequences for the overall scale of the NRMSE, hence, the cut-off values for the scoring were adjusted in the criteria score template (`crit_scores_tmpl`): from > 0.4 (score 0), > 0.1 (score 1) and <= 0.1 (score 2) to > 2 (score 0), > 1 (score 1) and <= 1 (score 2).

* The actual function for computing the NRMSE is now available as standalone function `nrmse()`; the function allows 4 different types of normalization and has as additional arguments for the specification of the type of transformation applied to the observations prior to the analysis. If the transformation is specified the function computes the NRMSE on the back-transformed observations and predictions, which is recommended for indicator cross-comparisons (see also [https://www.marinedatascience.co/blog/2019/01/07/normalizing-the-rmse/](https://www.marinedatascience.co/blog/2019/01/07/normalizing-the-rmse/).

* The internal `calc_nrmse()` has been rewritten so that it is a wrapper function of `nrmse()`. It not only serves as internal helper function for `model_gam()` and `model_gamm()` now, but can be used by the user to compute the NRMSE for all models using different settings than the default (i.e. using a different normalization method and allow partial back-transformations). The function takes as input the model list (e.g. `$model` in the final model tibble), a list of indicator values (e.g. the `$ind_test` vectors from the `ind_init()` function) and a list of pressure values (e.g. the `$press_test` vectors) to calculate first the predicted values given the model and pressure values, then -if specified- the back-transformation and finally the NRMSE for the individual models.

* All example data has been updated and include now the NRMSE based on the standard deviation and back-transformation if indicator time series were log-transformed.

* The function `dist_sc_group()` was added, which allows the calculation of the distance matrix averaged across groups, hence, it is like a weighted distance matrix.

* All functions incorporate now the tidy evaluation principles to account for the recent updates of dplyr, ggplot and all other tidyverse packages, i.e. 
		* all deprecated SE versions of the main tidyverse verbs have been replaced with the main verb and using `!!rlang::sym()`, to create symbols from the variables provided as strings and unquote them directly in the capturing functions (see https://github.com/r-lib/rlang/issues/116).
		* aesthetic mappings in internal ggplot functions were based on individual vectors (by setting `data = NULL`) in previous function. In the updated version aesthetic variables are provided in a data frame explicitly defined in the `data` argument and referred to using `!!rlang::sym()`.

## Bug fixes

* Fixed issue of missing acf and pacf diagnostic plots as soon as there were NAs in the acf vectors (happens if time series is very short).



# INDperform 0.1.1

* With the upcoming release of ggplot2 v2.3.0 we deactivated our visual tests to avoid conflicts between generated and references plots that would cause tests to fail.

* Minor modifications in the test files to pass all system checks on CRAN.

# INDperform 0.1.0

* All functions now have data input validation routines that will return detailed messages if the required input has not the correct format. This prevents potential error messages when running following functions.

* In all modeling functions potential error messages that occur as side effects in the model fitting are captured and printed out together with the model id, indicator and pressure variable or saved in the output tibble.

## Bug fixes

* `plot_spiecharts` now orders the pressure-specific slices correctly to the pressure types.

* All modeling functions can now handle all basic distribution families and some of the mgcv families.

* `expect_response` now returns the modified input tibble with the correct column names.

* In `model_gamm` the length of the outlier list to exclude (excl_outlier argument) is now correctly estimated in the data input validation routine.



