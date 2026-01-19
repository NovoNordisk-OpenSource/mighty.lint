#' Linter to detect dplyr joins without explicit 'by' argument
#'
#' This linter flags join operations (left_join, right_join, inner_join, etc.)
#' that don't explicitly specify the join keys via the 'by' argument.
#'
#' @param namespaces Character vector of package namespaces to check.
#'   Default includes "dplyr", "tidylog", and "dbplyr". Can be customized
#'   to include other packages that export join functions.
#' @return A linter function
#' @export
lint_implicit_join <- function(
  namespaces = c(
    "dplyr",
    "tidylog",
    "dbplyr"
  )
) {
  join_functions <- c(
    "left_join",
    "right_join",
    "inner_join",
    "full_join",
    "semi_join",
    "anti_join",
    "nest_join"
  )
  lintr::Linter(function(source_expression) {
    # Skip token-level processing because we need the complete AST structure
    # to properly analyze function calls and their arguments.
    if (!lintr::is_lint_level(source_expression, "expression")) {
      return(list())
    }

    # Use R's AST (represented as XML)
    xml <- source_expression$xml_parsed_content

    xpath_query <- .build_join_xpath_query(join_functions, namespaces)
    join_calls <- xml2::xml_find_all(xml, xpath_query)

    lints <- Negate(is.null) |>
      Filter(
        join_calls |>
          lapply(
            .check_join_node,
            source_expression = source_expression,
            namespaces = namespaces
          )
      )

    lints
  })
}


#' Check a single join node for implicit join
#'
#' Examines a join function call node to determine if it lacks an explicit
#' 'by' argument. Returns a Lint object if the join is implicit, NULL otherwise.
#'
#' @param call_node XML node representing the join function call
#' @param source_expression Source expression object from lintr
#' @param namespaces Character vector of allowed package namespaces
#' @return lintr::Lint object if join is implicit, NULL otherwise
#' @noRd
.check_join_node <- function(call_node, source_expression, namespaces) {
  # The AST nests function calls: SYMBOL_FUNCTION_CALL is wrapped in an expr,
  # which is wrapped in the full call structure that contains arguments.
  expr_node <- xml2::xml_parent(call_node)
  call_parent <- xml2::xml_parent(expr_node)

  # Filter by namespace: only check joins from specified packages
  call_namespace <- .get_call_namespace(expr_node)
  if (!is.null(call_namespace) && !call_namespace %in% namespaces) {
    return(NULL)
  }

  # Look for named 'by' argument.
  by_args <- xml2::xml_find_all(call_parent, ".//SYMBOL_SUB[text()='by']")

  # Return early if 'by' argument is present (explicit join)
  if (length(by_args) > 0) {
    return(NULL)
  }

  # Only implicit joins reach here
  function_name <- .extract_function_name(call_node)
  location <- .extract_safe_location(call_node, source_expression)

  .create_implicit_join_lint(
    source_expression,
    function_name,
    location
  )
}

#' Extract namespace from a function call node
#'
#' Determines the package namespace of a function call by examining the AST.
#' Returns NULL for bare function calls (no namespace), or the namespace string
#' for namespaced calls (e.g., "dplyr" from "dplyr::left_join").
#'
#' @param expr_node XML node representing the expression containing the call
#' @return Character string of namespace, or NULL if bare call or indeterminate
#' @noRd
.get_call_namespace <- function(expr_node) {
  # NS_GET is the AST node type that R's parser creates for the :: operator

  ns_get <- xml2::xml_find_first(expr_node, "./NS_GET")

  if (is.na(xml2::xml_name(ns_get))) {
    return(NULL) # Bare call (no namespace)
  }

  # Extract package name
  pkg_node <- xml2::xml_find_first(expr_node, "./SYMBOL_PACKAGE")
  if (!is.na(xml2::xml_name(pkg_node))) {
    return(xml2::xml_text(pkg_node))
  }
  return(NULL)
}

#' Build XPath query for finding join function calls
#'
#' Constructs an XPath query that matches both bare function calls
#' (e.g., left_join) and namespaced calls (e.g., dplyr::left_join).
#'
#' @param join_functions Character vector of join function names
#' @param namespaces Character vector of package namespaces to check
#' @return Character string containing XPath query
#' @noRd
.build_join_xpath_query <- function(join_functions, namespaces) {
  # Match bare function names and all specified namespace::function combinations
  conditions <- c(
    sprintf("text()='%s'", join_functions),
    unlist(lapply(namespaces, function(ns) {
      sprintf("text()='%s::%s'", ns, join_functions)
    }))
  )
  sprintf("//SYMBOL_FUNCTION_CALL[%s]", paste(conditions, collapse = " or "))
}

#' Extract function name including namespace if present
#'
#' Navigates the AST to determine if a function call includes a namespace
#' prefix (e.g., dplyr::) and returns the complete function name.
#'
#' @param call_node XML node representing the function call
#' @return Character string like "left_join" or "dplyr::left_join"
#' @noRd
.extract_function_name <- function(call_node) {
  function_name <- xml2::xml_text(call_node)

  parent_expr <- xml2::xml_parent(call_node)
  ns_get <- xml2::xml_find_first(parent_expr, "./NS_GET|./NS_GET_INT")

  if (is.na(xml2::xml_name(ns_get))) {
    return(function_name)
  }

  pkg_node <- xml2::xml_find_first(parent_expr, "./SYMBOL_PACKAGE")
  if (is.na(xml2::xml_name(pkg_node))) {
    return(function_name)
  }

  paste0(xml2::xml_text(pkg_node), "::", function_name)
}

#' Extract source location from AST node
#'
#' Extracts line number, column number, and line text from an AST node
#' with bounds checking for column positions.
#'
#' @param call_node XML node representing the function call
#' @param source_expression Source expression object from lintr
#' @return List with line_num, col_num, and line_text
#' @noRd
.extract_safe_location <- function(call_node, source_expression) {
  min_col <- 1L

  line_num <- as.integer(xml2::xml_attr(call_node, "line1"))
  col_num <- as.integer(xml2::xml_attr(call_node, "col1"))

  # Use file_lines which preserves all lines including blank lines,
  # maintaining the exact line numbering that matches the XML parser's
  # line1 attribute.

  all_file_lines <- source_expression$file_lines

  # Extract line text with fallback to empty string for out-of-bounds or NA
  line_text <- if (line_num >= 1 && line_num <= length(all_file_lines)) {
    all_file_lines[line_num]
  } else {
    ""
  }
  if (is.na(line_text)) {
    line_text <- ""
  }

  # Bounds checking prevents errors when IDE integrations try to highlight
  # the lint location in the editor.
  # Column positions are 1-indexed, and can point one position past the last
  # character (to indicate end-of-line position).
  if (col_num < min_col) {
    col_num <- min_col
  }
  max_col <- nchar(line_text) + 1L
  if (col_num > max_col) {
    col_num <- max_col
  }

  list(
    line_num = line_num,
    col_num = col_num,
    line_text = line_text
  )
}

#' Create a Lint object for implicit join violation
#'
#' Constructs a lintr::Lint object with appropriate message for joins
#' that lack explicit 'by' arguments.
#'
#' @param source_expression Source expression object from lintr
#' @param function_name Name of the join function (e.g., "left_join")
#' @param location List containing line_num, col_num, and line_text
#' @return lintr::Lint object
#' @noRd
.create_implicit_join_lint <- function(
  source_expression,
  function_name,
  location
) {
  lintr::Lint(
    filename = source_expression$filename,
    line_number = location$line_num,
    column_number = location$col_num,
    type = "warning",
    message = sprintf(
      "Join operation '%s' should explicitly specify join keys using the 'by' argument.",
      function_name
    ),
    line = location$line_text
  )
}
