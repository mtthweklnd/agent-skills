# S7 basics

(CRAN vignette: "S7 basics")

S7 is R's new OOP system, designed and implemented collaboratively by the RConsortium Object-Oriented Programming Working Group (R-Core, Bioconductor, RStudio/tidyverse, and the wider R community) as a successor to S3 and S4.

```r
library(S7)
```

## Classes and objects

S7 classes have a formal definition created with `new_class()`. Two arguments matter almost every time:

- `name` -- the class's name, as the first argument.
- `properties` -- the data each instance holds. Easiest form: a named list where each value is the property's type.

```r
Dog <- new_class("Dog", properties = list(
  name = class_character,
  age = class_numeric
))
Dog
```

Built-in definitions for existing base types that aren't themselves S7 classes all start with `class_`.

**Always assign the result of `new_class()` to a variable with the same name as the class** -- that object *is* the constructor:

```r
lola <- Dog(name = "Lola", age = 11)
lola
```

Get and set properties with `@`:

```r
lola@age <- 12
lola@age
```

Property types are validated automatically:

```r
lola@age <- "twelve"  # errors
```

Get an object's class with `S7_class()`:

```r
S7_class(lola)
```

S7 objects also have an S3 `class()` (for compatibility with existing S3 generics -- see `compatibility.md`):

```r
class(lola)
```

See `classes-and-objects.md` for validators and the finer details of properties.

## Generics and methods

Like S3 and S4, S7 is built around **generic functions**. A generic defines an interface; a different implementation (a **method**) runs depending on the class of one or more arguments, found via **method dispatch**.

`new_generic()` creates a generic. In its simplest form it needs only the generic's name and the dispatch argument's name:

```r
speak <- new_generic("speak", "x")
```

As with `new_class()`, assign the result to a variable with the same name as the first argument.

Register a method with `method(generic, class) <- implementation`:

```r
method(speak, Dog) <- function(x) "Woof"
speak(lola)
```

```r
Cat <- new_class("Cat", properties = list(name = class_character, age = class_double))
method(speak, Cat) <- function(x) "Meow"
fluffy <- Cat(name = "Fluffy", age = 5)
speak(fluffy)
```

Calling the generic with a class that has no method errors:

```r
speak(1)  # errors
```

## Method dispatch and inheritance

`Cat` and `Dog` share properties, so factor out a parent class:

```r
Pet <- new_class("Pet", properties = list(name = class_character, age = class_numeric))
Cat <- new_class("Cat", parent = Pet)
Dog <- new_class("Dog", parent = Pet)
```

Dispatch walks the parent-class hierarchy: if no method exists for a class, S7 tries the parent, and so on, until it finds one or errors.

```r
describe <- new_generic("describe", "x")
method(describe, Pet) <- function(x) paste0(x@name, " is ", x@age, " years old")
describe(lola)   # uses Pet's method
describe(fluffy)

method(describe, Dog) <- function(x) paste0(x@name, " is a ", x@age, " year old dog")
describe(lola)   # now uses Dog's more specific method
```

Register a method for `S7_object` to provide a fallback for *any* S7 object:

```r
method(describe, S7_object) <- function(x) "An S7 object"
```

Printing a generic shows which methods are currently registered; `method()` retrieves a specific implementation:

```r
describe
method(describe, Pet)
```

See `generics-and-methods.md` for full details on dispatch.
