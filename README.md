
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mighty.lint

<!-- badges: start -->

[![R-CMD-check](https://github.com/NovoNordisk-OpenSource/mighty.lint/actions/workflows/check_and_co.yaml/badge.svg)](https://github.com/NovoNordisk-OpenSource/mighty.lint/actions/workflows/check_and_co.yaml)
<!-- badges: end -->

## Overview

mighty.lint provides custom linters to help develop quality mighty
components. The package extends the lintr framework with specialized
checks for issues that arise when writing mighty components.

## Installation

You can install the development version of mighty.lint from GitHub:

``` r
# install.packages("devtools")
devtools::install_github("NovoNordisk-OpenSource/mighty.lint")
```

## Linters

### lint_implicit_join()

Detects dplyr join operations that do not explicitly specify join keys
using the `by` argument.

#### Usage

``` r
library(mighty.lint)

# Add to your .lintr configuration
linters:linters_with_defaults(
  implicit_join_linter = lint_implicit_join()
)
```

#### Examples

``` r
# Bad: implicit join (will be flagged)
result <- dplyr::left_join(df1, df2)

# Good: explicit join
result <- dplyr::left_join(df1, df2, by = "id")

# Good: explicit join with multiple keys
result <- dplyr::left_join(df1, df2, by = c("id", "name"))

# Good: explicit join with different column names
result <- dplyr::left_join(df1, df2, by = c("id" = "user_id"))
```

#### Supported Join Functions

The linter checks all dplyr join operations:

- `left_join()`
- `right_join()`
- `inner_join()`
- `full_join()`
- `semi_join()`
- `anti_join()`
- `nest_join()`

#### Configurable Namespaces

By default, the linter checks joins from `dplyr`, `tidylog`, and
`dbplyr` packages. You can customize this:

``` r
lint_implicit_join(
  namespaces = c("dplyr", "tidylog", "dbplyr", "custom.package")
)
```
