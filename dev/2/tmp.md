# NA

## Summary

This PR adds a new linter
[`lint_implicit_join()`](https://nn-opensource.github.io/Rtemplate/reference/lint_implicit_join.md)
that detects dplyr join operations missing explicit `by` arguments. The
need for this lint is stems from the bug report detailed here:
<https://github.com/NN-OpenSource/mighty/issues/97>

## Changes Made

- Add
  [`lint_implicit_join()`](https://nn-opensource.github.io/Rtemplate/reference/lint_implicit_join.md)
  linter function with support for all dplyr join types (left_join,
  right_join, inner_join, full_join, semi_join, anti_join, nest_join)
- Include configurable namespace support (defaults to dplyr, tidylog,
  and dbplyr)
- Add test suite
- Update DESCRIPTION file dependencies and correct URL
- Add initial README

## Related Issues

- <https://github.com/NN-OpenSource/mighty/issues/97>

## Testing

- Unit tests for basic implicit join detection (with and without
  namespace)
- Tests for all supported join types
- Tests for piped syntax with both \|\> and %\>%
- Tests for multiline joins and complex workflows
- Tests for joins with other arguments
- Tests for custom namespace configuration
- Tests for proper line number reporting
- Tests verifying non-join functions are not flagged

## Checklist

Code changes have been tested

Documentation has been updated, if applicable

All automated tests pass

Coding style and naming conventions have been followed

The PR is ready for review and merge

c,
