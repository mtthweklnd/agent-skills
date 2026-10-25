---
name: r-S7
description: Use when code loads or uses S7 (library(S7), S7::), defines S7 classes/properties via new_class()/new_property(), creates S7 generics/methods via new_generic()/method()<-, needs multiple dispatch, or makes S7 interoperate with S3/S4 in R
---

# Object-oriented programming in R with S7

S7 is R's RConsortium-backed OOP successor to S3/S4. Classes come from `new_class()` + properties; generics come from `new_generic()` + `method()<-`. Read `references/API.md` before writing code -- `references/` also has one file per topic/vignette for deeper detail.

## Quick Reference (`no mark`=required, `(opt)`=optional, `(adv)`=advanced)

|Function|Parameters|Purpose|
|---|---|---|
|`new_class()`|`name`, `properties`(may be empty), `parent`(opt, default `S7_object`), `validator`(opt), `constructor`(opt), `abstract`(opt), `package`(adv, set when exporting)|Define a class; assign result to a same-named var: `Foo <- new_class("Foo")`|
|`new_property()`|`class`(opt, default `class_any`), `default`(opt, value or `quote(expr)`), `getter`(opt), `setter`(opt, adds getter = dynamic prop), `validator`(opt), `name`(adv)|Define one property; getter w/o setter = read-only/computed|
|`new_generic()`|`name`, `dispatch_args`, `fun`(adv: add required/optional args, drop `...`; must call `S7_dispatch()`)|Define a generic|
|`method(generic, signature) <-`|signature: S7 class/union, `new_S3_class()`, S4 class, base `class_*`, or `list(...)` for multiple dispatch|Register a method|
|`method()`/`method_explain()`|`generic`, `class`/`object`|Introspect/debug which method wins|
|`super(from, to)`|`from`, `to` (superclass)|Dispatch the next call as if `from` were class `to` (static `NextMethod()`)|
|`methods_register()`|(package dev, adv)|Call in `.onLoad()` for cross-package method registration|

## Core Patterns & Pitfalls

- **Always assign**: `Foo <- new_class("Foo")` / `foo <- new_generic("foo", "x")` -- that variable *is* the constructor/generic.
- Properties: `obj@prop` / `prop()`. Batch-set with `props(obj) <- list(...)` or `set_props()` to validate once instead of per-assignment -- required if an intermediate single-property state would be invalid.
- Unions: `class_integer | class_double`; `NULL | class_integer` for optional/nullable.
- Fallbacks: `class_missing` (arg not supplied), `class_any` (default method).
- Multiple dispatch: `dispatch_args = c("x","y")`, then `method(generic, list(X, Y)) <- impl`.
- Methods with extra args need `...` on the generic (or on a custom `fun`), or registration warns/errors.
- S3/S4 interop: wrap S3 classes with `new_S3_class()` before using in `method()`/properties/unions (base ones are pre-wrapped, e.g. `class_data.frame`); S4 generics need `S4_register()` first.
- `convert(from, to)` ignores inheritance on `to` -- a method for a parent `to` does not cover a child `to`; write one per concrete target, or use `super()` for a one-off superclass call.
- Package dev: call `S7::methods_register()` in `.onLoad()`; export+document the constructor if users should create instances.
- **`class_environment` is properties-only.** `new_class("Foo", parent = class_environment)` errors ("Can't inherit from an environment") -- for mutable/pass-by-reference state, put the environment in a *property* (`properties = list(cache = class_environment)`), never in `parent`.
