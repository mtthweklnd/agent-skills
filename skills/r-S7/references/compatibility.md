# Compatibility with S3 and S4

(CRAN vignette: "Compatibility with S3 and S4")

```r
library(S7)
```

S7 is designed to be compatible with both S3 and S4.

## S3

S7 objects **are** S3 objects -- S7 is implemented on top of S3. Two differences from a plain S3 object:

- S7 objects have an additional `S7_class` attribute (besides `class`) that holds the object defining the class.
- S7 objects have *properties* (implemented on top of attributes, so `attr()` still works) rather than bare attributes. Inside S7 code, use `@`/`prop()`, never raw attributes directly -- but this layering is why existing S3-based code keeps working.

Consequently: S7 can register methods for an S7 class + S3 generic, or an S3 class + S7 generic; S7 classes can extend S3 classes; S3 classes can extend S7 classes.

### Methods

`method()` is the one tool you need for registering methods across systems. You can also register a method for an S7 class on an **S3 generic** without S7 at all, by relying on normal S3 dispatch (because every S7 object has an S3 class):

```r
Foo <- new_class("Foo")
class(Foo())              # has a normal S3 class vector

mean.Foo <- function(x, ...) "mean of foo"
mean(Foo())                # ordinary S3 dispatch finds it
```

### Classes

You can extend an S7 class with S3. This is useful for converting a class hierarchy "from the inside out": give an S3 class a formal S7 definition without needing to touch its existing S3 subclasses.

### List classes (e.g. converting something like `rle`)

Many simple S3 classes are just lists under the hood. Two ways to port one to S7:

**Keep the list structure**, enforced via a custom constructor:

```r
new_rle <- new_class("rle",
  parent = class_list,
  constructor = function(lengths, values) new_object(list(lengths = lengths, values = values))
)
```

**Convert to native S7 properties** (more idiomatic, but breaks `$`-based access unless you add a method):

```r
new_rle <- new_class("rle", properties = list(lengths = class_integer, values = class_atomic))
method(`$`, new_rle) <- prop   # restore `$name` access via properties
```

The property-based approach's downside: any existing subclasses of the original S3 class will also need converting to S7.

## S4

S7 properties are the equivalent of S4 slots, except properties can be dynamic (computed/validated via `getter`/`setter`).

- S7 classes **cannot** extend S4 classes.
- S4 classes **can** extend S3 classes (unrelated to S7, but relevant if mixing systems).
- S7 can register methods for: S7 class + S4 generic (needs `S4_register()` first -- see `references/API.md`), or S4 class + S7 generic.

### Unions

S4 unions are automatically converted to S7 unions, but the two systems apply unions at different times:

- **S4**: unions are resolved at *dispatch* time (`setUnion("u1", c("class1","class2"))` effectively makes `class1`/`class2` extend `u1`).
- **S7**: unions are resolved at *method-registration* time -- registering a method for a union is shorthand for registering the same method separately for each union member.

```r
Class1 <- new_class("Class1"); Class2 <- new_class("Class2")
Union1 <- new_union(Class1, Class2)
foo <- new_generic("foo", "x")
method(foo, Union1) <- function(x) ""   # registers for Class1 AND Class2
```

S7 unions also restrict a *property's* type to a set of classes, just as S4 unions restrict a slot's type.
