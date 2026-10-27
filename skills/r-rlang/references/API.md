# rlang environment API reference

Complete reference for rlang's `env_*` family and the environment-enhancement
functions that surround it (frame/call-stack accessors, search path, binding
locks, zap sentinels). Derived from the rlang 1.3.0 CRAN reference manual.
Read this before writing code that creates, inspects, or mutates environments
with rlang.

---

## Create environments

### `env()`

```r
env(...)
```

Creates a child of the **current environment** by default, populated from
named arguments in `...`.

- `...`: `<dynamic>` named values. Supply one *unnamed* argument to set a
  custom parent (defaults to `current_env()`). Supports splicing (`!!!`) and
  name-unquoting (`!!name :=`).

```r
env(a = 1, b = "foo")              # parent = current_env()
env(base_env(), a = 1)             # custom parent, unnamed first arg
objs <- list(b = "foo", c = "bar")
env(a = 1, !!!objs)                # splice a named list in
var <- "a"; env(!!var := "A")      # unquote a binding name
```

### `new_environment()`

```r
new_environment(data = list(), parent = empty_env())
```

Creates a child of the **empty environment** by default, populated from a
named *list* (not dots). This is the "`new_` constructor" pattern used
elsewhere in rlang — pass a data structure, not `...`.

```r
new_environment(list(a = "foo", b = "bar"))
```

Use `env()` for "a scope I'm building up with individual args, inheriting
from somewhere sensible"; use `new_environment()` for "a standalone
container, no inheritance by default."

### `as_environment()`

```r
as_environment(x, parent = NULL)
```

Coerces to an environment:

- Named vector/list -> environment of bindings. Names must be unique.
- Unnamed string -> looked up as a package name via `pkg_env()`.
- `NULL` -> `empty_env()`.
- An environment with a non-`NULL` `parent` -> **a clone** with the new
  parent (not the original object — side-effect-free).

`parent` (opt): defaults to `empty_env()`; only applies when `x` is data
being coerced (not when `x` already denotes an environment like `NULL`).

```r
as_environment(mtcars)            # parent = empty_env()
as_environment("rlang")           # shortcut for pkg_env("rlang")
```

### `child_env()` — *deprecated*

`child_env(.parent, ...)`. Superseded by `env()`, which now accepts a parent
as the unnamed first argument. Don't use in new code; you'll see it in older
examples/snippets.

---

## Inspect environments

### `is_environment()` / `is_bare_environment()`

```r
is_environment(x)             # any environment (incl. S4/R6 objects etc.)
is_bare_environment(x)        # environment with no S3/S4 class attached
```

### `env_print()`

```r
env_print(env = caller_env())
```

Pretty-prints: label + parent label, lock status, up to 20 bindings (tagged
`<lazy>`/`<active>`/`[L]` for locked), using `pillar::type_sum()` if
available. Printing a package namespace shows `<lazy>` for functions not yet
force-loaded from disk.

### `env_name()` / `env_label()`

```r
env_name(env)     # "global" / "empty" / "base" / "namespace:pkg" /
                   # the `name` attribute / "" otherwise
env_label(env)    # like env_name(), but falls back to the memory
                   # address for anonymous environments
```

### `env_names()` / `env_length()`

```r
env_names(env)     # character vector of ALL bound names (incl. dot-prefixed)
env_length(env)    # number of bindings
```

`env_names()` always returns UTF-8, translating ASCII-escaped unicode points
back — relevant on Windows where symbols are kept in native encoding.

### `env_depth()`

```r
env_depth(env)
```

Number of environments between `env` and `empty_env()`, inclusive of `env`.
Equivalently, the number of parents of `env` (the empty environment counts).

### `env_inherits()`

```r
env_inherits(env, ancestor)
```

`TRUE` if `ancestor` is anywhere in `env`'s parent chain.

### `env_is_user_facing()`

```r
env_is_user_facing(env)
```

`TRUE` if `env` inherits from the global environment (interactive call) or
from a package currently under test — i.e., the frame was called *directly*
by the end user rather than indirectly through a third-party function. Used
by e.g. the lifecycle package to pick deprecation-warning verbosity.
Override globally with `options(rlang_user_facing = TRUE/FALSE/"pkgname")`.

---

## Query & manipulate bindings

### `env_has()`

```r
env_has(env = caller_env(), nms, inherit = FALSE)
```

Vectorised predicate. `inherit = FALSE` (default): does `env` *personally*
own each binding. `inherit = TRUE`: does `env` or any parent see it. Returns
a named logical vector.

### `env_get()` / `env_get_list()`

```r
env_get(env = caller_env(), nm, default, inherit = FALSE, last = empty_env())
env_get_list(env = caller_env(), nms, default, inherit = FALSE, last = empty_env())
```

- `nm`/`nms`: binding name(s), string(s).
- `default` (opt): returned instead of erroring if the binding is missing.
- `inherit` (opt): search parent environments.
- `last` (opt, adv): stop searching here when `inherit = TRUE` — useful with
  `base::topenv()` to avoid walking past a namespace boundary.

Errors if the binding doesn't exist and no `default` is given.
`env_get_list()` returns a named list for several bindings at once.

### `env_cache()`

```r
env_cache(env, nm, default)
```

`env_get()` + `env_poke()` combined: if `nm` exists in `env`, return it;
otherwise store `default` in `env` and return that. The idiomatic
memoization pattern (e.g., for package-level caches in `.onLoad()`).

### `env_bind()` and friends

```r
env_bind(.env, ...)
env_bind_active(.env, ...)
env_bind_lazy(.env, ..., .eval_env = caller_env())
lhs %<~% rhs
```

| Variant | Equivalent to | `...` takes |
|---|---|---|
| `env_bind()` | `base::assign()` / `<-` | named **values** |
| `env_bind_active()` | `base::makeActiveBinding()` | named **functions** (or formulas, via `as_function()`) |
| `env_bind_lazy()` | `base::delayedAssign()` | named **expressions**, captured with `exprs()` (supports `!!!`/unquoting) |
| `%<~%` | shortcut for one lazy binding | `name %<~% expr` |

- `.env`: environment to bind into.
- Use `zap()` as a value in `env_bind()`'s `...` to **remove** a binding
  (unambiguous vs. `NULL`, which is a valid value).
- Active bindings re-run their function on every access; the function is
  scoped in its own enclosure, which it can close over independently of the
  environment it's installed in — this is how `dplyr::do()`-style dynamic
  proxies work.
- Lazy bindings evaluate their expression once, on first access, in
  `.eval_env` (default: the environment calling `env_bind_lazy()`, *not*
  `.env`) — then cache the forced value.
- **Return value**: the *old* values, invisibly (side-effecty, like
  `options()`/`par()`). Save them to restore state later:
  `old <- env_bind(e, a = 1); env_bind(e, !!!old)`.

```r
env <- env()
env_bind_active(env, symbol = function() rnorm(1))  # re-rolls every access
env_bind_lazy(env, name = { cat("forced!\n"); "value" })  # forced once
env_bind(env, foo = zap())                            # remove `foo`
```

### `env_poke()`

```r
env_poke(env = caller_env(), nm, value, inherit = FALSE, create = !inherit)
```

Single-binding assign/reassign.

- `inherit` (opt): search parent environments for an existing binding to
  reassign.
- `create` (opt, adv): whether to create the binding if absent. Defaults to
  `!inherit` — i.e., when `inherit = TRUE` the intent is usually "update an
  existing binding somewhere up the chain," so a miss is an error by default.
  **Unlike base `<<-`**, which silently falls through to create a binding in
  the *global* environment, `env_poke(inherit = TRUE)` errors instead of
  guessing — safer when you don't want to accidentally pollute globalenv.
- Returns the old value, or a `zap()` sentinel if the binding was new.

### `env_poke_parent()` / `get_env()` / `set_env()`

```r
get_env(env, default = NULL)
set_env(env, new_env = caller_env())
env_poke_parent(env, new_env)
```

- `get_env()` extracts the environment from an object with dispatch for
  functions, formulas, frames; called on a bare environment it's the
  identity. `default` (opt) avoids an error when the object doesn't bundle
  one yet (e.g., an unevaluated formula).
- `set_env()` returns a **modified copy** (no side effects) — reassign the
  result. For quosures specifically, prefer `quo_get_env()`/`quo_set_env()`.
- `env_poke_parent()` mutates `env`'s parent **by side effect** (environments
  are uncopyable) — be careful not to do this to an environment you don't
  own, such as a function's enclosure from another package.

### `env_unbind()`

```r
env_unbind(env = caller_env(), nms, inherit = FALSE)
```

Complement of `env_bind()`. Ignores parents unless `inherit = TRUE`, in
which case it removes the binding wherever in the chain it's found.

### `env_bury()` — *superseded*

```r
env_bury(.env, ...)
```

Like `env_bind()` but returns a **new** environment: a clone of `.env`
enclosed by a fresh child holding the new bindings, so the new bindings
shadow (bury) the old ones without mutating anything. Superseded — prefer
`env()` directly (plus `set_env()` if you need to re-point a closure/formula
at the result):

```r
# superseded
fn <- env_bury(fn, a = 1000)
# preferred
fn <- set_env(fn, env(get_env(fn), a = 1000))
```

---

## Clone & merge

### `env_clone()`

```r
env_clone(env, parent = env_parent(env))
```

New environment with the **same bindings** as `env` (active bindings and
promises preserved), optionally re-parented. Mutating the clone never
affects the original — this is the escape hatch from reference semantics
when you need a snapshot.

### `env_coalesce()`

```r
env_coalesce(env, from)
```

Copies bindings from `from` into `env`, **keeping** any binding already
present in `env` under the same name (first-write-wins). To instead let
`from` win, clear the conflicting names first:
`env_unbind(env, env_names(from)); env_coalesce(env, from)`.

---

## Hierarchy / parents

### `env_parent()` / `env_parents()` / `env_tail()`

```r
env_parent(env = caller_env(), n = 1)
env_parents(env = caller_env(), last = global_env())
env_tail(env = caller_env(), last = global_env())
```

- `env_parent()`: the `n`-th ancestor (`n = 2` -> grandparent).
- `env_parents()`: **list** of all parents up to and including
  `empty_env()`, named via `env_name()`.
- `env_tail()`: the environment whose parent is `empty_env()` (the root of
  the chain).
- `last` (opt): where `env_parents()`/`env_tail()` stop looking (default
  `global_env()`); `empty_env()` always stops the search regardless, so the
  default is safe even on search-path environments.
- Called with no `env` argument inside a function, `env_parent()` returns
  that function's **enclosure** (the parent of its own execution frame) —
  the common case for "what environment is my function's lexical scope."

---

## Locking

### `env_lock()` / `env_is_locked()`

```r
env_lock(env)
env_is_locked(env)
```

Locks the environment **as a container**: no bindings can be added or
removed. Existing bindings' *values* can still be changed (`env$a <- 10`
still works) unless those bindings are individually locked too. Namespaces
are locked by R on load. Locking normally cannot be undone.

### `env_binding_lock()` / `env_binding_unlock()` / `env_binding_are_locked()`

```r
env_binding_lock(env, nms = NULL)
env_binding_unlock(env, nms = NULL)
env_binding_are_locked(env, nms = NULL)
```

Per-binding locks (vs. `env_lock()`'s container-level lock): a locked
binding errors on reassignment attempts (`<-`, `env_bind()`). `nms` (opt)
defaults to all bindings. Lock/unlock return the *previous* lock state of
each named binding, invisibly.

### `env_binding_are_active()` / `env_binding_are_lazy()`

```r
env_binding_are_active(env, nms = NULL)
env_binding_are_lazy(env, nms = NULL)
```

Introspect binding *kind* (active vs. lazy-promise vs. plain) — useful
before printing/serializing an environment's contents, since forcing an
active or lazy binding has side effects.

### `env_unlock()` — *defunct*

No-op/error now; recent R no longer supports unlocking a locked environment.

### `env_browse()` / `env_is_browsed()` — *defunct*

Previously set persistent step-debugging on an environment. No longer
functional; use `debug()`/`browser()` directly.

---

## Frame & call-stack accessors

```r
current_call();  current_fn();  current_env()
caller_call(n = 1);  caller_fn(n = 1);  caller_env(n = 1)
frame_call(frame = caller_env());  frame_fn(frame = caller_env())
```

Naming scheme: **prefix** picks *which* frame (`current_` = this one,
`caller_` = `n` frames back, `frame_` = an arbitrary frame you already hold a
reference to); **suffix** picks *what* to retrieve (`_fn` = running
function, `_call` = the defused call it was invoked with, `_env` = its
execution environment). `n` (opt): how many callers to walk back.
`frame_*` take a `frame` environment (as returned by `caller_env()`) and
return `NULL` if it's no longer on the stack.

These are the environment-aware building blocks behind most rlang defaults
(`caller_env()` is the default `env`/`.env` argument all over the `env_*`
family above) — prefer them over base `sys.call()`/`parent.frame()` when
writing package code, since they compose cleanly with quasiquotation and
tidy eval.

---

## Special / named environments

```r
global_env();  base_env();  empty_env()
search_envs();  search_env(name);  is_attached(x)
pkg_env(pkg);  pkg_env_name(pkg)
ns_env(x = caller_env());  ns_imports_env(x = caller_env());  ns_env_name(x = caller_env())
```

- `global_env()` / `base_env()`: aliases for `globalenv()`/`baseenv()`,
  respectively the first and last environments on the **search path**.
- `empty_env()`: the only environment with no parent; always the eventual
  tail of any chain (search path included).
- `search_envs()`: all search-path environments as a list (vs. base
  `search()`, which only gives names).
- `search_env(name)` / `pkg_env(pkg)`: look up one search-path environment
  by its `"package:pkg"` name, or by bare package name respectively.
  `pkg_env()` errors if the package isn't attached (use `ns_env()` instead
  for an unattached package's internals).
- `is_attached(x)`: is a search name / environment on the search path.
- `ns_env(x)`: the **namespace** environment of a package — where all its
  functions actually live (as opposed to `pkg_env()`, the attached/exported
  view). `x` can be a package name string, an environment/function to
  search upward from via `base::topenv()` (default: `caller_env()`).
  `ns_imports_env(x)`: the namespace's parent, holding everything it
  imported from other packages.
- `ns_registry_env()` — *defunct*.
- `scoped_env(nm)` / `is_scoped(nm)` — *deprecated*, use `is_attached()`.

---

## Evaluate within an environment

```r
with_env(env, expr)      # deprecated
locally(expr)             # deprecated; prefer base::local()
local_bindings(..., .env = .frame, .frame = caller_env())
with_bindings(.expr, ..., .env = caller_env())
```

- `with_env()`/`locally()` are **deprecated** thin wrappers around
  `eval_bare()` with lighter stack semantics than `base::eval()`/`local()`
  (no extra evaluation-stack frame, so non-local `return()` tricks work) —
  still worth knowing when reading older code, but prefer `base::local()`
  or explicit `eval_bare()` in new code.
- `local_bindings()`: temporarily rebinds `...` names in `.env`, automatically
  restoring the old values when `.frame` is popped off the call stack (i.e.,
  scoped to the *caller's* lifetime, not a `with_env` block). `with_bindings()`
  wraps it around a single expression and restores immediately after.

```r
foo <- "foo"
with_bindings(paste(foo, "bar"), foo = "rebinded")   # "rebinded bar"
paste(foo)                                            # back to "foo"
```

---

## Sentinels

```r
zap()
is_zap(x)
```

`zap()` is an unambiguous "delete this" marker for `env_bind()`,
`call_modify()`, etc. — unlike `NULL`/`missing_arg()`, it can never be
confused with a real value someone wants to assign.

```r
env_bind(e, foo = zap())                         # remove one binding
zaps <- rep_named(c("foo", "bar"), list(zap()))
env_bind(e, !!!zaps)                             # remove several, spliced
```

---

## Where environments meet tidy eval

`eval_tidy(expr, data = NULL, env = caller_env())` is the data-masking
cousin of `base::eval()` — it wraps `data` into a **data mask** (an
environment chain built with `as_data_mask()`/`new_data_mask()`) instead of
simply coercing it to a plain environment. See
`references/environments-deep-dive.md` for how data masks, quosures, and the
`.data`/`.env` pronouns build on everything above.
