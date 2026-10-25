# Classes and objects

(CRAN vignette: "Classes and objects" -- builds on `s7-basics.md`)

```r
library(S7)
```

## Validation

S7 classes can have an optional **validator**: `function(self)` that returns `NULL` if the object is valid, or a character vector of problems.

```r
Range <- new_class("Range",
  properties = list(start = class_double, end = class_double),
  validator = function(self) {
    if (length(self@start) != 1) {
      "@start must be length 1"
    } else if (length(self@end) != 1) {
      "@end must be length 1"
    } else if (self@end < self@start) {
      sprintf("@end (%i) must be greater than or equal to @start (%i)", self@end, self@start)
    }
  }
)
```

Write validators as ordered `if`-`else` chains -- order matters (you can't compare `@start`/`@end` before confirming both are length 1). Prefer per-property validators (below) for single-property checks; reserve the class validator for checks that span *multiple* properties.

**When validation runs:** automatically on construction and whenever any property is set via `@<-`.

```r
x <- Range(1, 2:3)   # errors: end isn't length 1
x <- Range(10, 1)    # errors: end < start

x <- Range(1, 10)
x@start <- 20         # errors: would make end < start
```

You can also call `validate()` manually, e.g. after bypassing `@` with low-level attribute manipulation:

```r
x <- Range(1, 2)
attr(x, "start") <- 3
validate(x)
```

### Avoiding validation on intermediate states

A function that updates two properties in sequence can trip validation on a step that's transiently invalid even though the end state is fine:

```r
shift <- function(x, shift) {
  x@start <- x@start + shift
  x@end <- x@end + shift
  x
}
shift(Range(1, 10), 10)  # errors partway through
```

Fix by setting all properties at once with `props<-`, which validates only once, after every property is updated:

```r
shift <- function(x, shift) {
  props(x) <- list(start = x@start + shift, end = x@end + shift)
  x
}
shift(Range(1, 10), 10)  # works
```

(`valid_eventually()` is the lower-level tool behind this pattern -- see `references/API.md`.)

## Properties

The named-list shorthand (`properties = list(start = class_double)`) is shorthand for a full `new_property()` call:

```r
Range <- new_class("Range",
  properties = list(
    start = new_property(class_double),
    end = new_property(class_double)
  )
)
```

Call `new_property()` explicitly to control validation, defaults, computed values, or full dynamic behavior.

### Per-property validation

```r
prop_number <- new_property(
  class = class_double,
  validator = function(value) if (length(value) != 1L) "must be length 1"
)
Range <- new_class("Range",
  properties = list(start = prop_number, end = prop_number),
  validator = function(self) {
    if (self@end < self@start) sprintf("@end (%i) must be >= @start (%i)", self@end, self@start)
  }
)
```

Property validators should **not** include the property's name in their message -- S7 prepends it automatically. This also lets one property definition (like `prop_number` above) be reused across multiple properties.

### Default values

Without a custom default, properties default to an "empty" instance of their class, so a class can be constructed with no arguments at all:

```r
Empty <- new_class("Empty", properties = list(x = class_double, y = class_character, z = class_logical))
Empty()
```

Supply your own default via `default`:

```r
Empty <- new_class("Empty", properties = list(
  x = new_property(class_numeric, default = 0),
  y = new_property(class_character, default = ""),
  z = new_property(class_logical, default = NA)
))
```

A **quoted call** becomes a function promise evaluated at construction time (not when the class is defined):

```r
Stopwatch <- new_class("Stopwatch", properties = list(
  start_time = new_property(class_POSIXct, default = quote(Sys.time())),
  elapsed = new_property(getter = function(self) difftime(Sys.time(), self@start_time, units = "secs"))
))
```

### Computed properties

A `getter` computes a property's value on demand instead of storing it:

```r
Range <- new_class("Range", properties = list(
  start = class_double,
  end = class_double,
  length = new_property(getter = function(self) self@end - self@start)
))
```

Computed properties (getter, no setter) are **read-only**: `x@length <- 20` errors.

### Dynamic properties

Add a `setter` (`function(self, value)` returning a modified object) to make a computed property writable too:

```r
Range <- new_class("Range", properties = list(
  start = class_double,
  end = class_double,
  length = new_property(
    class = class_double,
    getter = function(self) self@end - self@start,
    setter = function(self, value) {
      if (!length(value)) return(self)  # ignore constructor's default zero-length call
      self@end <- self@start + value
      self
    }
  )
))
```

### Common patterns

Combine `getter`, `setter`, `default`, and `validator` for recurring needs:

**Deprecated properties** -- `getter`+`setter` that warn, delegating to the real property:

```r
Person <- new_class("Person", properties = list(
  first_name = class_character,
  firstName = new_property(
    class_character,
    default = quote(first_name),
    getter = function(self) { warning("@firstName is deprecated; use @first_name"); self@first_name },
    setter = function(self, value) { warning("@firstName is deprecated; use @first_name"); self@first_name <- value; self }
  )
))
```

**Required properties** -- make the default a quoted error, or rely on a validator:

```r
Person <- new_class("Person", properties = list(
  name = new_property(class_character, default = quote(stop("@name is required")))
))
try(Person())        # errors: name required
Person("Alice")      # fine
```

**Frozen (read-only-after-construction) properties** -- a `setter` that errors if already set:

```r
Person <- new_class("Person", properties = list(
  birth_date = new_property(class_Date, setter = function(self, value) {
    if (!is.null(self@birth_date)) stop("@birth_date is read-only", call. = FALSE)
    self@birth_date <- as.Date(value)
    self
  })
))
person <- Person("1999-12-31")
try(person@birth_date <- "2000-01-01")  # errors
```

## Constructors

Inspect a class's generated constructor via its `constructor` property:

```r
Range@constructor
```

The default constructor is usually enough. For custom construction logic (e.g. computing `start`/`end` from an arbitrary numeric vector):

```r
Range <- new_class("Range",
  properties = list(start = class_numeric, end = class_numeric),
  constructor = function(x) {
    new_object(S7_object(), start = min(x, na.rm = TRUE), end = max(x, na.rm = TRUE))
  }
)
Range(c(10, 5, 0, 2, 5, 7))
```

Rules: a custom constructor must end with `new_object()`. Its first argument must be an instance of the `parent` class (or `S7_object()` if no `parent` was given), followed by one named argument per property. **Caveat:** any subclass of a class with a custom constructor will also need its own custom constructor.
