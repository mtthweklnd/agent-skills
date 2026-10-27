# Environments as objects: concepts, patterns, pitfalls

rlang ships no CRAN vignettes for the `env_*` family (the manual pages in
`API.md` *are* the documentation), so this file collects the cross-cutting
concepts the help pages state individually but don't connect, plus patterns
that come up repeatedly in package code.

## 1. Reference semantics — the one thing to never forget

Environments are **not copied** on assignment or on being passed to a
function. `e2 <- e1` gives you a second name for the same object; mutating
through either reference mutates both.

```r
e1 <- env(a = 1)
e2 <- e1
env_bind(e2, a = 99)
e1$a   # 99 -- not 1
```

This is *why* `env_bind()`, `env_poke()`, `env_unbind()`, `env_poke_parent()`,
and `env_binding_lock()`/`env_lock()` are described as having "side
effects" and return old values invisibly (mirroring `options()`/`par()`) —
there is no return value representing "the new environment" because the
environment you passed in already *is* the new one.

**Escape hatches** when you need a snapshot instead of a shared reference:

- `env_clone(env)` — copy-on-demand, preserves active/lazy bindings.
- `set_env(fn, new_env)` / `set_env(quo, new_env)` — returns a modified
  *copy* of the function/quosure/formula (the wrapping object is copied;
  the environment it now points to may itself still be shared with others).
- `as_environment(x, parent = new_parent)` on an existing environment `x`
  clones before reparenting, specifically so `as_environment()` is never a
  silent-mutation trap.

Everything else in the `env_*` family mutates in place. Document this
loudly in any function you write that accepts an environment argument and
calls `env_bind()`/`env_poke()`/etc. on it — callers will not expect their
environment to change unless you say so.

## 2. Inheritance vs. membership: `inherit = TRUE/FALSE`

Nearly every query function (`env_has()`, `env_get()`, `env_get_list()`,
`env_unbind()`) defaults to `inherit = FALSE`: it looks *only* at bindings
the environment personally owns, never its parents. This is deliberately
stricter than `exists()`/`get()`, whose default (`inherits = TRUE`) walks
the whole lexical scope chain and is a common source of bugs when you meant
to check one specific environment.

```r
parent <- env(empty_env(), foo = "foo")
child  <- env(parent, bar = "bar")

env_has(child, "foo")                 # FALSE -- child doesn't own it
env_has(child, "foo", inherit = TRUE)  # TRUE  -- but sees it via parent
```

Reach for `inherit = TRUE` only when you explicitly want lexical-scope
lookup semantics (e.g., reproducing what `<-`/`<<-` would resolve to).

## 3. `env_poke(inherit = TRUE)` vs. base `<<-`

Base R's `<<-` walks up the parent chain looking for an existing binding to
reassign; if it reaches the global environment without finding one, it
*creates* the binding there — a well-known footgun (a typo'd variable name
silently pollutes globalenv instead of erroring).

`env_poke(env, nm, value, inherit = TRUE)` walks the same chain, but its
`create` argument defaults to `!inherit`, i.e. `FALSE` when inheriting: a
miss **errors** instead of falling through to a create-in-globalenv
surprise. Pass `create = TRUE` explicitly if you genuinely want
`<<-`-style create-on-miss behavior with a known target.

## 4. Frames vs. environments vs. the call stack

An execution **frame** is a point on the call stack; it has an associated
environment (the function's local bindings), the call that invoked it, and
the function object itself. Environments *outlive* frames (a closure keeps
its enclosing environment alive after the frame that created it has
popped); frames only exist while a function is running.

- `current_env()` / `caller_env(n)` / `frame_fn(frame)` etc. (see
  `API.md` → *Frame & call-stack accessors*) are the rlang way to query
  "where am I / who called me" — prefer them over
  `environment()`/`sys.function()`/`parent.frame()` in package code,
  because they're what every `env = caller_env()` default elsewhere in
  rlang is built on, and they read more clearly at call sites.
- `env_parent(env)` with no `env` argument, called inside a function,
  returns that function's **enclosure** — not a "caller" in the dynamic
  sense, but the lexical parent of the function's own execution
  environment. Don't confuse this with `caller_env()`, which gives you the
  *dynamic* caller (who invoked this function at runtime) — the two
  frequently coincide for simple top-level calls but diverge the moment a
  function is called from inside another function, or stored and invoked
  later via a callback.

## 5. The search path, package environments, and namespaces

Three different "environment for package X" concepts, easy to conflate:

| Concept | Function | Contains |
|---|---|---|
| Attached/search-path env | `pkg_env("x")` | Only `x`'s **exports**; only exists if `x` is attached via `library()` |
| Namespace env | `ns_env("x")` | **All** of `x`'s functions, exported or not — what runs when `x`'s own code calls its own internals |
| Imports env | `ns_imports_env("x")` | Parent of the namespace; everything `x` imported from its dependencies |

`pkg_env()` errors if `x` isn't attached. `ns_env()` works regardless of
attachment (it just needs the package installed/loaded) and is almost
always what you want when writing tooling that inspects *another*
package's internals, since you can't assume the user has attached it.

The search path itself (`search_envs()`) is the chain the R console walks
to resolve a bare name typed interactively: `global_env()` first,
`base_env()` last, every `library()`'d package's `pkg_env()` in between,
terminating at `empty_env()`.

## 6. Binding kinds: plain, active, lazy/promise — and why it matters for printing or serializing

A binding can be:

- **Plain** — a normal value.
- **Active** (`env_bind_active()`) — re-executes a zero-arg function on
  every access; the function closes over its *own* defining environment,
  independent of where the active binding lives, which is how you build a
  computed/dynamic field.
- **Lazy / promise** (`env_bind_lazy()`, `%<~%`) — evaluates its expression
  once, on first access, then caches the forced value. Built on
  `base::delayedAssign()`.

Querying `env_binding_are_active()`/`env_binding_are_lazy()` *before*
printing, serializing, or iterating over an environment's bindings matters
because forcing either kind has side effects (it runs code) — `env_print()`
already does this defensively, tagging un-forced bindings as `<active>` or
`<lazy>` rather than evaluating them just to display a value.

## 7. Locking: container-level vs. binding-level

Two independent lock axes, both "experimental" per the docs but stable in
practice:

- `env_lock(env)` locks the **container**: no bindings can be added or
  removed, but existing bindings' *values* remain mutable
  (`env$existing <- newval` still works). This is what R does automatically
  to namespace environments on load.
- `env_binding_lock(env, nms)` locks **specific bindings**: those specific
  names become immutable (reassignment errors), independent of whether the
  container itself is locked.

Combine both for a fully frozen environment (no new names, no changed
values): `env_lock(env); env_binding_lock(env)`.

## 8. How this connects to tidy evaluation / data masking

Environments-as-scopes is the mechanism tidy eval is built on. The pieces,
in terms of what's in `API.md`:

- A **quosure** is an expression bundled with an environment (its lexical
  scope at capture time) — conceptually like a closure's enclosure, but for
  an unevaluated expression rather than a function body.
- `eval_tidy(expr, data, env)` evaluates `expr` (plain or quosure) inside a
  **data mask**: a purpose-built environment chain where `data`'s names are
  bound ahead of (take precedence over) `env`'s. This is literally the
  "child environment shadows its parent" rule from `env()`'s *Inheritance*
  section, applied deliberately so data-frame columns can mask
  same-named objects in the surrounding scope.
- The `.data`/`.env` pronouns installed in the mask are an explicit escape
  hatch for that same shadowing — `.data$x` forces "the column," `.env$x`
  forces "the enclosing-scope object," when the ambiguity itself is the
  problem.
- Because `eval_tidy()` always evaluates inside this extra mask
  environment (even when `data = NULL`), it has different stack semantics
  than `base::eval()`: assignment happens in the mask, not `env`, and stack
  -sensitive functions like bare `return()` don't behave as if called
  directly from `env`. If you need the full picture, this is the point at
  which `env_*` fundamentals end and tidy-eval-specific documentation
  (`?as_data_mask`, `?new_data_mask`, `?enquo`) begins.

## 9. Common mistakes checklist

- Passing an environment into a helper and being surprised the caller's
  copy changed too — there is no copy; see §1.
- Using the default `inherit = FALSE` and being surprised a binding
  "isn't there" when it's actually one level up in the parent chain — see
  §2.
- Relying on `<<-`-style auto-create in `env_poke(inherit = TRUE)` without
  passing `create = TRUE` — it will error instead, by design; see §3.
- Confusing `env_parent()` (lexical enclosure) with `caller_env()` (dynamic
  caller) — they coincide at the top level and diverge inside nested calls;
  see §4.
- Calling `pkg_env("somepkg")` on a package that's merely *installed*, not
  *attached* — use `ns_env("somepkg")` instead when you can't assume
  `library()` was called.
- Forgetting that `env_lock()` only freezes the *container*; existing
  bindings can still have their values swapped unless individually locked
  with `env_binding_lock()` too.
- Using `NULL` as a "delete this" marker in `env_bind()`'s `...` — `NULL`
  is a legitimate value to bind; use `zap()` to unambiguously signal
  removal.
