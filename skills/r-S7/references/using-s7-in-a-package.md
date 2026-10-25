# Using S7 in a package

(CRAN vignette: "Using S7 in a package")

```r
library(S7)
```

The author's note: S7 is new, so package usage patterns are still evolving; this vignette may be incomplete.

## Method registration

**Always** call `methods_register()` in your package's `.onLoad()`:

```r
.onLoad <- function(...) {
  S7::methods_register()
}
```

This is how S7 registers methods -- it does not rely on `NAMESPACE` export directives the way S3/S4 do. Strictly required only if you register methods for generics defined in *other* packages, but add it unconditionally: it's harmless, prevents future surprises, and (if S7 isn't in your `Imports`) silences an `R CMD check` NOTE.

## Documentation and exports

- To let users create instances of your class, **export the constructor** -- and document it. Since the constructor is a function, document its arguments (which are the class's properties, unless you've customized the constructor).
- If you export a class, **set the `package` argument** to `new_class()` so classes with the same name across packages don't collide.
- Document generics like regular functions (they are). If you expect other packages/users to write methods for your generic, consider documenting what properties/arguments all methods are expected to support.
- There's no required documentation for individual methods to pass `R CMD check`, though documenting a method that adds extra arguments beyond the generic can help.

## Backward compatibility (R < 4.3.0)

`@` only works with S4 objects on R versions before 4.3.0. Two workarounds if your package needs to support those versions:

1. Use `prop()` instead of `@` everywhere (simplest, least convenient).
2. Add this `NAMESPACE` directive so `@` works for your package's own code and for your users:

```r
#' @rawNamespace if (getRversion() < "4.3.0") importFrom("S7", "@")
NULL
```

S7 automatically attaches the environment needed to make `@` work for downstream users once it is loaded, so this directive is only needed for the package itself to compile/check cleanly on old R.
