# S7 API Reference

Complete function reference for S7 (CRAN, version 0.2.2). Mirrors the package's `.Rd` help pages. Aliases that share one help page are grouped together.

---

## `new_class()` / `new_object()` -- Define a new S7 class

A class specifies the properties (data) each of its objects will possess. The class, and its parent, determines which method will be used when an object is passed to a generic. Learn more in `vignette("classes-objects")`.

```r
new_class(
  name,
  parent = S7_object,
  package = topNamespaceName(parent.frame()),
  properties = list(),
  abstract = FALSE,
  constructor = NULL,
  validator = NULL
)

new_object(.parent, ...)
```

**Arguments**

- `name` -- The name of the class, as a string. The result of calling `new_class()` should always be assigned to a variable with this name, i.e. `Foo <- new_class("Foo")`.
- `parent` -- The parent class to inherit behavior from. One of: an S7 class (e.g. `S7_object`); an S3 class wrapped by `new_S3_class()`; a base type (`class_logical`, `class_integer`, ...).
- `package` -- Package name. Auto-resolved if the class is defined in a package, `NULL` otherwise. If the class is for external use, export the constructor (see `vignette("packages")`).
- `properties` -- A named list specifying the properties (data) that belong to each instance. Each element is either a type specification (processed by `as_class()`) or a full spec from `new_property()`.
- `abstract` -- Is this an abstract class? An abstract class cannot be instantiated.
- `constructor` -- Custom constructor function. Default constructor has one argument per property. A custom constructor must call `new_object()`; its first argument `.data` should be an instance of the parent class (if used), followed by arguments that set properties.
- `validator` -- `function(self)`. Determines whether the object's property *values* (or combination of values) are valid -- property *types* are always checked automatically. Return `NULL` if valid, else a character vector where each element describes one problem (use `@prop_name` to reference a property). Called after construction and whenever any property is set. See `validate()`.
- `.parent`, `...` (for `new_object()`) -- Parent object and named properties used to construct the object.

**Value:** An object constructor -- a function used to create instances of the class.

**Example**

```r
Range <- new_class("Range",
  properties = list(start = class_numeric, end = class_numeric),
  validator = function(self) {
    if (length(self@start) != 1) "@start must be a single number"
    else if (length(self@end) != 1) "@end must be a single number"
    else if (self@end < self@start) "@end must be great than or equal to @start"
  }
)
r <- Range(start = 10, end = 20)
r@start
r@end <- 40
try(Range(start = c(10, 15), end = 20))
try(r@start <- 25)
```

---

## `new_property()` -- Define a new property

A property defines a named component of an object, typically used to store (meta)data limited to a specific `class`. Supplying a `getter`/`setter` makes a property "dynamic" (computed on access, or with custom write behavior); dynamic properties are excluded from the default constructor's arguments. See "Properties: Common Patterns" in `vignette("classes-objects")`.

```r
new_property(
  class = class_any,
  getter = NULL,
  setter = NULL,
  validator = NULL,
  default = NULL,
  name = NULL
)
```

**Arguments**

- `class` -- Class the property must be an instance of (processed by `as_class()`).
- `getter` -- `function(self)` returning the value; you are responsible for its correctness (not auto-validated). A property with a getter but no setter is **read-only**.
- `setter` -- `function(self, value)` returning the modified object.
- `validator` -- `function(value)`. Returns `NULL` if valid, else a single string describing the problem (don't include the property name -- it's prepended automatically). Runs after the `class` check, so `value` has a known type.
- `default` -- Value used when the property is not supplied at construction. If `NULL`, defaults to the "empty" instance of `class`. Can be a quoted call (`quote(expr)`), which becomes a function promise evaluated at construction time.
- `name` -- Property name (for error messages). Usually set implicitly via the list name; if both are given, the list name wins.

**Value:** An S7 property (a list of class `S7_property`).

**Example**

```r
Pizza <- new_class("Pizza", properties = list(slices = new_property(class_numeric, default = 10)))
my_pizza <- Pizza(slices = 6)
my_pizza@slices <- 5

Clock <- new_class("Clock", properties = list(now = new_property(getter = function(self) Sys.time())))
try(Clock()@now <- 10)  # read-only
try(Clock(now = 10))    # dynamic properties aren't constructor args
```

---

## `new_generic()` / `S7_dispatch()` -- Define a new generic

A generic function uses different implementations (*methods*) depending on the class of one or more arguments (the *signature*). Create a generic with `new_generic()`, then add methods with `method<-`. Dispatch is performed by `S7_dispatch()`, which must always appear in the generic's body (`new_generic()` generates this for you in most cases). Learn more in `vignette("generics-methods")`.

```r
new_generic(name, dispatch_args, fun = NULL)

S7_dispatch()
```

**Arguments**

- `name` -- Name of the generic; should match the variable it's assigned to.
- `dispatch_args` -- Character vector of argument name(s) used to find the method. One name = single dispatch; more than one = multiple dispatch. Dispatch arguments must be the first arguments to the generic, and if `...` is present it must immediately follow them.
- `fun` -- Optional custom generic body; must call `S7_dispatch()`. Usually auto-generated, but supply your own to add extra required arguments, add optional arguments after `...`, omit `...` entirely, or run standardized pre-dispatch logic.

**Value:** An S7 generic (a function of class `S7_generic`).

**See also:** `new_external_generic()` to add methods for a generic in another package without a hard dependency.

**Example**

```r
type_of <- new_generic("type_of", dispatch_args = "x")
method(type_of, class_character) <- function(x, ...) "A character vector"
method(type_of, new_S3_class("data.frame")) <- function(x, ...) "A data frame"
type_of(mtcars)

# Require an extra argument on every method, via a custom `fun`:
mean2 <- new_generic("mean2", "x", function(x, ..., na.rm = FALSE) S7_dispatch())
method(mean2, class_numeric) <- function(x, ..., na.rm = FALSE) {
  if (na.rm) x <- x[!is.na(x)]
  sum(x) / length(x)
}
```

---

## `method()` -- Find a method for an S7 generic

`method()` takes a generic and class signature and performs method dispatch to find the corresponding implementation. Rarely needed directly (the generic dispatches for you), but useful for introspection.

```r
method(generic, class = NULL, object = NULL)
```

**Arguments**

- `generic` -- An S7, external, S3, or S4 generic.
- `class`, `object` -- Introspect via a `class` (processed by `as_class()`) or a concrete `object`. For multiple-dispatch generics, both must be a `list()` of classes/objects.

**Value:** A function of class `S7_method`, or an error if no method matches.

**See also:** `method_explain()` to explain *why* a method was picked.

**Example**

```r
bizarro <- new_generic("bizarro", "x")
method(bizarro, class_numeric) <- function(x) rev(x)
method(bizarro, class = class_integer)   # inspect via class
method(bizarro, object = 1)              # inspect via object
try(method(bizarro, class = class_data.frame))  # errors: not found
```

---

## `method<-` -- Register an S7 method for a generic

Once a generic exists (`new_generic()`), register implementations for specific signatures with `method<-`. This is the single function needed for registering methods: S7 class on S7/S3/S4 generic, or S3/S4 class on S7 generic (at least one of `generic`/`signature` must be from S7).

**If writing a package, call `methods_register()` in `.onLoad()`** so methods register dynamically as needed.

```r
method(generic, signature) <- value
```

**Arguments**

- `generic` -- An S7, external, S3, or S4 generic.
- `signature` -- The method signature. For S7 generics with single dispatch: an S7 class, an S7 union (`new_union()`), an S3 class (`new_S3_class()`), an S4 class, a base type (`class_logical`, `class_integer`, ...), or a special type (`class_missing`, `class_any`). For multiple dispatch: a `list()` of any of the above. For S3 generics: a single S7 class. For S4 generics: an S7 class, or a list including at least one S7 class.
- `value` -- A function implementing the generic for `signature`.

**Value:** `generic`, invisibly.

**Example**

```r
bizarro <- new_generic("bizarro", "x")
method(bizarro, class_numeric) <- function(x) rev(x)
method(bizarro, new_S3_class("data.frame")) <- function(x) { x[] <- lapply(x, bizarro); rev(x) }
bizarro(head(mtcars))
```

---

## `as_class()` -- Standard class specifications

The interface between S7 and R's other OO systems, allowing S7 classes/methods to work with base types, informal S3 classes, and formal S4 classes.

```r
as_class(x, arg = deparse(substitute(x)))
```

- `x` -- A class spec: S7 class, S7 union, S3 class (`new_S3_class()`), S4 class, base class (`class_logical`, ...), or a "special" (`class_missing`/`class_any`).
- `arg` -- Argument name used in error messages.

**Value:** A standardized class -- `NULL`, an S7 class, an S7 union, a `new_S3_class`, or an S4 class.

```r
as_class(class_logical)
as_class(new_S3_class("factor"))
```

---

## Base-type class wrappers (`class_*`)

S7 wrappers that let base types participate in S7 classes/dispatch:

`class_logical`, `class_integer`, `class_double`, `class_complex`, `class_character`, `class_raw`, `class_list`, `class_expression`, `class_name`, `class_call`, `class_function`, `class_environment`.

**`class_environment` cannot be used as `new_class()`'s `parent`** -- `new_class("Foo", parent = class_environment)` errors with "Can't inherit from an environment." It can only restrict a *property*'s type (e.g. `properties = list(cache = class_environment)`). If you need a class with mutable, pass-by-reference semantics, store the environment as a property instead of inheriting from one.

Built-in unions:
- `class_numeric` = `class_integer | class_double`
- `class_atomic` = `class_logical | class_numeric | class_complex | class_character | class_raw`
- `class_vector` = `class_atomic | class_list | class_expression`
- `class_language` = `class_name | class_call`

```r
class_integer
class_numeric
class_factor
```

## Base S3-class wrappers

S7 bundles S3 definitions for key base S3 classes: `class_data.frame`, `class_Date`, `class_factor`, `class_POSIXct`, `class_POSIXlt`, `class_POSIXt`, `class_formula`.

## `class_any` -- Dispatch on any class

Register a default/fallback method, called when no other method matches.

```r
foo <- new_generic("foo", "x")
method(foo, class_numeric) <- function(x) "number"
method(foo, class_any) <- function(x) "fallback"
foo(1); foo("x")
```

## `class_missing` -- Dispatch on a missing argument

Matches when an argument was not supplied at all (`missing()`-style), not `NA`/`is.na()`.

```r
foo <- new_generic("foo", "x")
method(foo, class_numeric) <- function(x) "number"
method(foo, class_missing) <- function(x) "missing"
method(foo, class_any) <- function(x) "fallback"
foo(); foo("")
```

---

## `convert()` -- Convert an object from one type to another

Built-in generic for converting an object between types. Special in three ways: double-dispatch (depends on both `from` and `to`); non-standard dispatch (`to` is a class, not an object); does **not** use inheritance for `to` (methods written for a parent class return parent-class objects, not subclass objects). Plays a role similar to S3 `as.foo()` or S4 `as()`/`setAs()`.

If converting purely to access a superclass method, prefer `super()` instead.

```r
convert(from, to, ...)
```

- `from` -- An S7 object to convert.
- `to` -- An S7 class spec, passed to `as_class()`.
- `...` -- Passed to custom `convert()` methods; for upcasting, can override/set properties.

**Default behavior:** downcasting (when `from` inherits from `to`) strips extra properties; upcasting (when `to` is a subclass of `from`'s class) creates a `to` object, copying existing properties and initializing new ones. All other conversions require an explicit method.

```r
Foo1 <- new_class("Foo1", properties = list(x = class_integer))
Foo2 <- new_class("Foo2", Foo1, properties = list(y = class_double))

convert(Foo2(x = 1L, y = 2), to = Foo1)                      # downcast
convert(Foo1(x = 1L), to = Foo2, y = 2.5)                    # upcast + set new prop

method(convert, list(Foo1, class_integer)) <- function(from, to) from@x
convert(Foo1(x = 1L), to = class_integer)

# Note: conversion is NOT inheritance-aware for `to`
method(convert, list(class_integer, Foo1)) <- function(from, to) Foo1(x = from)
convert(1L, to = Foo1)      # works
try(convert(1L, to = Foo2)) # still errors -- Foo2 needs @y too
```

---

## `method_explain()` -- Explain method dispatch

Shows every possible method a generic call might use, which exist, and which will actually be called. Useful for debugging dispatch (especially multiple dispatch). Each class system uses its own string convention: S7 is `pkg::class`/`class`; S4 is `S4/pkg::class`/`S4/class`; S3 is `class`.

```r
method_explain(generic, class = NULL, object = NULL)
```

Arguments mirror `method()`. Called for its side effect (prints an explanation); returns nothing.

```r
Foo1 <- new_class("Foo1")
Foo2 <- new_class("Foo2", Foo1)
add <- new_generic("add", c("x", "y"))
method(add, list(Foo2, Foo1)) <- function(x, y) c(2, 1)
method(add, list(Foo1, Foo1)) <- function(x, y) c(1, 1)
method_explain(add, list(Foo2, Foo2))
```

---

## `methods_register()` -- Register methods in a package

Call in your package's `.onLoad()` so methods you've implemented for generics (S3, S4, S7) in *other* packages register correctly when needed. Not strictly necessary if you only register methods for generics defined in your own package, but harmless and recommended.

```r
methods_register()
```

```r
.onLoad <- function(...) {
  S7::methods_register()
}
```

---

## `new_S3_class()` -- Declare an S3 class

S3 has no formal class definition, so to use an S3 class with S7 you must declare it (unless it's already covered by the base S3-class wrappers above).

```r
new_S3_class(class, constructor = NULL, validator = NULL)
```

- `class` -- S3 class vector (what `class()` returns). For method registration this can be abbreviated to a single class-name string.
- `constructor` -- Optional constructor, needed only if an S7 class should inherit from this S3 class, or the S3 class is used as a property *without* a default. First argument must be `.data`; all arguments need defaults so a no-arg call returns a valid "empty" object.
- `validator` -- Optional `function(object)` used by `validate()`; return `NULL` if valid or a character vector of problems. You are responsible for validating attribute types yourself (S7 does not do this for S3 wrappers).

**Three lightweight uses needing only the class vector:** registering an S3 method for an S7 generic; restricting a property to an S3 class; using an S3 class inside an S7 union -- all can be written inline, e.g. `method(my_generic, new_S3_class("factor")) <- function(x) ...`.

**Extending an S3 class** (more work) requires a constructor following S7 conventions:

```r
S3_Date <- new_S3_class("Date",
  function(.data = integer()) .Date(.data),
  function(self) if (!is.numeric(self)) "Underlying data must be numeric"
)
```

```r
Date <- new_S3_class("Date")  # dispatch-only, no checking
my_generic <- new_generic("my_generic", "x")
method(my_generic, Date) <- function(x) "This is a date"
my_generic(Sys.Date())
```

---

## `new_external_generic()` -- Generics in other packages

Use when you want to provide methods for a generic (S3, S4, or S7) defined in another package *without* a hard dependency on it. Provides the minimal info needed to register methods at runtime (via `methods_register()`). In tests, call the external generic explicitly as `pkg::generic()`.

```r
new_external_generic(package, name, dispatch_args, version = NULL)
```

- `package` -- Package the generic is defined in.
- `name` -- Generic's name, as a string.
- `dispatch_args` -- Character vector of dispatch argument names.
- `version` -- Optional minimum version of `package` required for the method to register.

```r
MyClass <- new_class("MyClass")
your_generic <- new_external_generic("stats", "median", "x")
method(your_generic, MyClass) <- function(x) "Hi!"
```

---

## `new_union()` -- Define a class union

A class union represents a list of possible classes: `new_union(a, b, c)` or shorthand `a | b | c`. Used to (1) let a property be one of several classes -- e.g. `NULL | class_integer` for an "optional" property; the union's default is the constructor of its *first* member -- and (2) define a method for multiple classes at once: `method(foo, X | Y) <- f` is shorthand for separate registrations per class. Built-in unions: `"numeric"`, `"atomic"`, `"vector"` (see base-type wrappers above).

```r
new_union(...)
```

```r
logical_or_character <- class_logical | class_character
Foo <- new_class("Foo", properties = list(x = logical_or_character))
Foo(x = TRUE); Foo(x = letters[1:5]); try(Foo(1:3))

bar <- new_generic("bar", "x")
method(bar, class_atomic) <- function(x) "Hi!"
```

---

## `prop()` / `prop<-` / `@` -- Get/set a property

```r
prop(object, name)
prop(object, name, check = TRUE) <- value
object@name
```

- `object` -- An S7 object.
- `name` -- Property name as a character string. No partial matching.
- `check` -- If `TRUE` (default), validates `value`'s type and re-runs `validate()` before returning.
- `value` -- New property value; the object is checked for validity after replacement.

```r
Horse <- new_class("Horse", properties = list(name = class_character, colour = class_character, height = class_numeric))
lexington <- Horse(colour = "bay", height = 15, name = "Lex")
lexington@colour
lexington@height <- 14
```

## `prop_names()` / `prop_exists()` -- Property introspection

```r
prop_names(object)
prop_exists(object, name)
```

`prop_names()` returns a character vector of property names; `prop_exists()` returns a single `TRUE`/`FALSE`.

## `props()` / `props<-` / `set_props()` -- Get/set multiple properties

```r
props(object, names = prop_names(object))
props(object, check = TRUE) <- value
set_props(object, ..., .check = TRUE)
```

- `props(x)` returns all (or selected) properties as a named list.
- `props(x) <- list(...)` sets multiple properties **and validates only once**, after all are applied -- use this (or `set_props()`) instead of chained `@<-` when intermediate states would be invalid or validation is costly.
- `set_props(x, ...)` returns a *copy* of `x` with the given properties changed.
- `check`/`.check` -- run `validate()` before returning (default `TRUE`).

```r
props(lexington) <- list(height = 14, name = "Lexington")
```

---

## `S4_register()` -- Register an S7 class with S4

Call once per class if you want to use `method<-` to register a method for an **S4 generic** on an S7 class.

```r
S4_register(class, env = parent.frame())
```

- `class` -- An S7 class (from `new_class()`).
- `env` -- Expert use only: environment where the S4 class is registered.

```r
methods::setGeneric("S4_generic", function(x) standardGeneric("S4_generic"))
Foo <- new_class("Foo")
S4_register(Foo)
method(S4_generic, Foo) <- function(x) "Hello"
```

## `S7_class()` -- Retrieve the S7 class of an object

```r
S7_class(object)
```

Returns the S7 class of `object`.

## `S7_data()` / `S7_data<-` -- Get/set underlying "base" data

When an S7 class inherits from an existing base type, access the underlying object (stripped of class and properties) with `S7_data()`.

```r
S7_data(object)
S7_data(object, check = TRUE) <- value
```

```r
Text <- new_class("Text", parent = class_character)
y <- Text(c(foo = "bar"))
S7_data(y)
S7_data(y) <- c("a", "b")
```

## `S7_inherits()` / `check_is_S7()` -- Test S7 inheritance

```r
S7_inherits(x, class = NULL)
check_is_S7(x, class = NULL, arg = deparse(substitute(x)))
```

- `S7_inherits()` returns `TRUE`/`FALSE`. With `class = NULL`, tests only whether `x` is *any* S7 object.
- `check_is_S7()` throws an error if `x` is not of `class` (or not an S7 object at all).

**Note:** on R >= 4.3.0, `base::inherits(x, Foo)` also works directly with an S7 class as the second argument.

## `S7_object()` -- Base S7 class

The base class every S7 class eventually inherits from (the default `parent` for `new_class()`).

```r
S7_object()
```

## `super()` -- Force dispatch to a superclass

`super(from, to)` makes the *next* generic call dispatch using the method for superclass `to` instead of `from`'s actual class. Needed to implement a method in terms of its superclass's implementation. Pass the result of `super()` straight into a generic call -- it has no other behavior.

Compared to S3's `NextMethod()` / S4's `callNextMethod()`: the superclass is fixed **statically** (known when you write the code, not when the generic runs), and all arguments must be passed explicitly. More verbose, but far easier to reason about.

```r
super(from, to)
```

- `from` -- An S7 object to cast.
- `to` -- Class spec (via `as_class()`); must be a superclass of `from`.

**Important:** `super()` does not work inside methods for an **S3 generic** (e.g. `print()`), because S3 dispatch doesn't understand S7's special wrapper object. Use `S7_data()` to get the underlying base object instead in that case.

```r
Foo1 <- new_class("Foo1", properties = list(x = class_numeric, y = class_numeric))
Foo2 <- new_class("Foo2", Foo1, properties = list(z = class_numeric))
total <- new_generic("total", "x")
method(total, Foo1) <- function(x) x@x + x@y
# Use super() to call the parent method instead of duplicating logic or looping forever:
method(total, Foo2) <- function(x) total(super(x, to = Foo1)) + x@z
total(Foo2(1, 2, 3))
```

Contrast with `convert()`: `super()` only affects the *next* generic call; `convert()` permanently changes the object's effective class for *every* subsequent generic call.

---

## `validate()` / `valid_eventually()` / `valid_implicitly()` -- Validate an S7 object

`validate()` calls the class's `validator` (from `new_class()`) to check an object is valid. Runs automatically on construction and whenever a property is set via `@<-`/`prop<-`/`props<-`.

```r
validate(object, recursive = TRUE, properties = TRUE)
valid_eventually(object, fun)
valid_implicitly(object, fun)
```

- `object` -- An S7 object.
- `recursive` -- If `TRUE`, also runs parent classes' validators.
- `properties` -- If `TRUE` (default), checks property *types* before running the validator.
- `fun` -- A function applied to `object` before validation runs.

`valid_eventually(object, fun)` disables validation, applies `fun`, then validates once at the end -- useful when a sequence of edits would otherwise pass through a temporarily-invalid state, or when per-step validation is a performance bottleneck.

`valid_implicitly(object, fun)` is the same but skips the final validation entirely -- use rarely, only in performance-critical code where you're certain the result can't be invalid.

```r
Range <- new_class("Range",
  properties = list(start = class_double, end = class_double),
  validator = function(self) if (self@start >= self@end) "start must be smaller than end"
)
r <- Range(1, 2)
try(r@end <- 1)  # blocked: would be invalid

# Move a range without tripping validation on an intermediate state:
rightwards <- function(r, x) {
  valid_eventually(r, function(object) {
    object@start <- object@start + x
    object@end <- object@end + x
    object
  })
}
rightwards(r, 10)

# Or equivalently, batch-set with props<- (validates once, at the end):
rightwards2 <- function(r, x) { props(r) <- list(start = r@start + x, end = r@end + x); r }
```
