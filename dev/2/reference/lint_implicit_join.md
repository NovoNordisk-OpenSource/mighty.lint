# Linter to detect dplyr joins without explicit 'by' argument

This linter flags join operations (left_join, right_join, inner_join,
etc.) that don't explicitly specify the join keys via the 'by' argument.

## Usage

``` r
lint_implicit_join(namespaces = c("dplyr", "tidylog", "dbplyr"))
```

## Arguments

- namespaces:

  Character vector of package namespaces to check. Default includes
  "dplyr", "tidylog", and "dbplyr". Can be customized to include other
  packages that export join functions.

## Value

A linter function
