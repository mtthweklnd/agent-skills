# Generics and methods

(CRAN vignette: "Generics and methods" -- builds on `s7-basics.md`)

```r
library(S7)
```

## Generic-method compatibility

When you register a method, S7 checks that its formal arguments agree with the generic's:

- Any argument the generic has, the method must have too (the method's arguments start with the generic's dispatch arguments, and those must not have default values).
- The method can add arguments the generic doesn't have, **only if** the generic includes `...`.

### Generic with `...`; method without `...`

The default generic includes `...`, but methods generally should not -- this stops misspelled arguments from being silently swallowed (unlike S3):

```r
mean <- new_generic("mean", "x")
method(mean, class_numeric) <- function(x) sum(x) / length(x)
mean(100, na.rm = TRUE)  # errors: na.rm not recognized
```

A method *can* still add its own extra arguments:

```r
method(mean, class_numeric) <- function(x, na.rm = TRUE) {
  if (na.rm) x <- x[!is.na(x)]
  sum(x) / length(x)
}
mean(c(100, NA), na.rm = TRUE)
```

### Generic and method both with `...`

Needed when a method must recursively re-call the generic, e.g. a `list` method that dispatches on each element:

```r
simple_print <- new_generic("simple_print", "x")
method(simple_print, class_double) <- function(x, ..., digits = 3) {}
method(simple_print, class_character) <- function(x, ..., max_length = 100) {}
method(simple_print, class_list) <- function(x, ...) for (el in x) simple_print(el, ...)

simple_print(list(1, 2, "x"), digits = 3)  # works: unknown args are silently ignored
```

This means methods using `...` will silently ignore misspelled arguments meant for *other* methods -- an unavoidable trade-off (barring `rlang::check_dots_used()`-style tooling).

### Generic and method without `...`

Occasionally useful: a generic lacking `...` guarantees that any call succeeding for one input type succeeds for all types. Requires a custom `fun` (third argument to `new_generic()`) that calls `S7_dispatch()`:

```r
length <- new_generic("length", "x", function(x) S7_dispatch())
```

This is a strong restriction (no method can add extra arguments) -- reserve it for low-level functions with precisely defined semantics (like base `length()`).

## Customizing generics

Supplying just `name` and `dispatch_args` to `new_generic()` auto-generates the generic's body. You can instead supply `fun` to:

- Drop `...` from the generic's formals (above).
- Add **required** arguments -- any argument without a default:

```r
foo <- new_generic("foo", "x", function(x, y, ...) S7_dispatch())
# methods now must accept `y` too, or you'll get a warning
```

- Add **optional** arguments -- put them *after* `...` so callers must name them explicitly:

```r
mean <- new_generic("mean", "x", function(x, ..., na.rm = TRUE) S7_dispatch())
method(mean, class_integer) <- function(x, na.rm = TRUE) {
  if (na.rm) x <- x[!is.na(x)]
  sum(x) / length(x)
}
```

Methods that omit the argument, or use a different default, get a warning.

- Do extra validation before dispatch:

```r
mean <- new_generic("mean", "x", function(x, ..., na.rm = TRUE) {
  if (!identical(na.rm, TRUE) && !identical(na.rm, FALSE)) stop("`na.rm` must be TRUE or FALSE")
  S7_dispatch()
})
```

The custom `fun` must always call `S7_dispatch()` (typically as the last line). The trade-off of pre-dispatch validation: it constrains every method's interface, even if a particular method would've been fine with a different argument type.

## `super()`

Use `super()` to implement a method in terms of its superclass's implementation -- fills a role similar to S3's `NextMethod()` or S4's `callNextMethod()`, but the superclass is fixed explicitly and statically:

```r
mean <- new_generic("mean", "x")
method(mean, class_numeric) <- function(x) sum(x) / length(x)

date <- new_class("date", parent = class_double)
method(print, date) <- function(x) print(.Date(x))

method(mean, date) <- function(x) date(mean(super(x, to = class_double)))
mean(date(c(1, 10, 100)))
```

Unpacked: `super(x, to = class_double)` makes the *next* generic call treat `x` as a `class_double`; the recursive `mean()` call then hits the numeric method instead of looping back into the date method; the numeric result is wrapped back into a `date`.

## Multiple dispatch

Supply a `dispatch_args` vector of length >= 2 to dispatch on more than one argument's class:

```r
Pet <- new_class("Pet"); Dog <- new_class("Dog", Pet); Cat <- new_class("Cat", Pet)
Language <- new_class("Language"); English <- new_class("English", Language); French <- new_class("French", Language)

speak <- new_generic("speak", c("x", "y"))
method(speak, list(Dog, English)) <- function(x, y) "Woof"
method(speak, list(Cat, English)) <- function(x, y) "Meow"
method(speak, list(Dog, French)) <- function(x, y) "Ouaf Ouaf"
method(speak, list(Cat, French)) <- function(x, y) "Miaou"

speak(Cat(), English())
speak(Dog(), French())
```

Multiple dispatch is common in S4, rare (but occasionally useful) in S7. Two special "classes" matter here: `class_any()` matches any class, and `class_missing()` matches an argument that wasn't supplied.
