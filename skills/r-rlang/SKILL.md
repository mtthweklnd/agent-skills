---
name: r-rlang
description: Use when code loads or uses rlang (library(rlang), rlang::), especially its env_* family -- env_bind(), env_poke(), env_get(), env_has(), env_clone(), env_parent(), env_unbind(), env_lock()/env_binding_lock(), caller_env(), current_env(), global_env(), ns_env() -- or any environment-as-object manipulation, scoping, or frame/call-stack introspection in R
---

# Environment manipulation with rlang

rlang treats environments as first-class, mutable, reference-semantics
objects and gives them a consistent `env_*` verb-based API (vs. base R's
scattered `assign()`/`get()`/`exists()`/`environment()`/`<<-`). Read
`references/API.md` before writing code -- it is the complete reference for
every `env_*` function plus the frame/call-stack and search-path accessors
that surround it. Read `references/environments-deep-dive.md` for cross-
cutting concepts (reference semantics, inheritance vs. membership, frames
vs. environments, locking, and how this connects to tidy eval/data masking)
and a mistakes checklist.

## Quick Reference (`no mark`=required, `(opt)`=optional, `(adv)`=advanced)

|Function|Parameters|Purpose|
|---|---|---|
|`env()`|`...`(dynamic named values; one unnamed = parent)|New child of **current env**, populate from dots|
|`new_environment()`|`data`(opt, named list), `parent`(opt, default `empty_env()`)|New child of **empty env**, populate from a list|
|`as_environment()`|`x`, `parent`(opt, default `empty_env()`)|Coerce named vector/list/string/`NULL` to an environment|
|`env_has()`|`env`(opt, default `caller_env()`), `nms`, `inherit`(opt, default `FALSE`)|Vectorised: does env (or its parents) own these names|
|`env_get()` / `env_get_list()`|`env`(opt), `nm`/`nms`, `default`(opt), `inherit`(opt), `last`(adv, default `empty_env()`)|Fetch one/many bindings; errors if missing w/o `default`|
|`env_cache()`|`env`, `nm`, `default`|Get-or-store memoization helper|
|`env_bind()`|`.env`, `...`(dynamic named values; `zap()` to remove)|Assign/reassign plain bindings (like `<-`)|
|`env_bind_active()`|`.env`, `...`(named functions/formulas)|Computed bindings, re-run on every access|
|`env_bind_lazy()`|`.env`, `...`(named exprs), `.eval_env`(opt, default `caller_env()`)|Promise bindings, forced once on first access|
|`env_poke()`|`env`(opt), `nm`, `value`, `inherit`(opt), `create`(opt, default `!inherit`)|Assign/reassign a **single** binding|
|`env_poke_parent()`|`env`, `new_env`|Mutate `env`'s parent **by side effect** (careful — not yours to break)|
|`get_env()` / `set_env()`|`env`/`x`, `default`(opt) / `new_env`(opt, default `caller_env()`)|Get/set environment of fn, formula, quosure, frame (`set_env` returns a copy)|
|`env_unbind()`|`env`(opt), `nms`, `inherit`(opt)|Remove bindings|
|`env_clone()`|`env`, `parent`(opt, default `env_parent(env)`)|Copy-on-demand: new env, same bindings, no shared mutation|
|`env_coalesce()`|`env`, `from`|Copy bindings from `from` into `env`, existing names in `env` win|
|`env_parent()` / `env_parents()` / `env_tail()`|`env`(opt), `n`(opt, default `1`) / `last`(opt, default `global_env()`)|Walk up the parent chain (one step / full list / to the root)|
|`env_depth()`|`env`|Count of parents down to `empty_env()`|
|`env_inherits()`|`env`, `ancestor`|Is `ancestor` anywhere in `env`'s parent chain|
|`env_lock()` / `env_is_locked()`|`env`|Freeze the **container** (no add/remove; values still mutable)|
|`env_binding_lock()` / `_unlock()` / `_are_locked()`|`env`, `nms`(opt, default all)|Freeze **specific bindings**' values|
|`env_binding_are_active()` / `_are_lazy()`|`env`, `nms`(opt)|Introspect binding kind before printing/forcing|
|`env_print()`|`env`(opt, default `caller_env()`)|Pretty-print label, parent, lock state, bindings|
|`env_name()` / `env_label()`|`env`|Special name ("global"/"base"/"namespace:pkg") or memory-address fallback|
|`env_names()` / `env_length()`|`env`|All bound names (incl. dot-prefixed) / count|
|`is_environment()` / `is_bare_environment()`|`x`|Type predicates|
|`current_env()` / `current_call()` / `current_fn()`|—|This frame's env / invoking call / running function|
|`caller_env()` / `caller_call()` / `caller_fn()`|`n`(opt, default `1`)|`n` frames back|
|`frame_call()` / `frame_fn()`|`frame`(opt, default `caller_env()`)|Properties of an arbitrary held frame env|
|`global_env()` / `base_env()` / `empty_env()`|—|Search-path ends / the parentless root|
|`search_envs()` / `search_env()` / `is_attached()`|`name` / `x`|Search path as list / lookup by name / attached predicate|
|`pkg_env()` / `pkg_env_name()`|`pkg`|Attached package's **exports** env (errors if not attached)|
|`ns_env()` / `ns_imports_env()` / `ns_env_name()`|`x`(opt, default `caller_env()`)|Package **namespace** (all fns) / its imports env — works unattached|
|`env_is_user_facing()`|`env`|Was this frame called directly by the end user (vs. indirectly)|
|`local_bindings()` / `with_bindings()`|`...`, `.env`/`.frame`(opt) / `.expr`|Temporarily rebind, auto-restore on frame exit|
|`zap()` / `is_zap()`|`x`|Unambiguous "delete this" sentinel (vs. ambiguous `NULL`)|
|`env_bury()`(adv, superseded)|`.env`, `...`|Bind in a new *shadowing* child instead of mutating — prefer `env()`+`set_env()`|
|`with_env()` / `locally()`(adv, deprecated)|`env`, `expr`|Lighter-stack-footprint eval; prefer `base::local()` in new code|

## Core patterns & pitfalls

- **Reference semantics, always**: `e2 <- e1; env_bind(e2, a = 1)` mutates
  `e1` too — there is no copy. `env_bind()`/`env_poke()`/`env_unbind()`/
  `env_poke_parent()`/lock functions all mutate in place and return the
  *old* state invisibly. Need a snapshot instead? Use `env_clone()`.
- **`inherit` defaults to `FALSE`** on every query (`env_has()`,
  `env_get()`, `env_unbind()`): these check what the environment *itself*
  owns, not the full lexical chain. Pass `inherit = TRUE` only when you
  explicitly want scope-walking lookup.
- **`env_poke(inherit = TRUE)` is the safe `<<-`**: it errors on a miss
  instead of silently creating the binding in `global_env()`. Pass
  `create = TRUE` only if you really want create-on-miss.
- Use `zap()`, not `NULL`, to mark a binding for removal in `env_bind()`'s
  `...` — `NULL` is a valid value and would just assign `NULL`.
- `env_parent()` (no `env` arg, called inside a function) = the function's
  **lexical enclosure**; `caller_env()` = the **dynamic** caller. They
  coincide for simple top-level calls and diverge the moment calls are
  nested or deferred (callbacks, promises) — don't conflate them.
- `pkg_env("x")` requires `x` to be **attached** (`library(x)`) and only
  exposes its exports; `ns_env("x")` works regardless of attachment and
  exposes everything, including internals — prefer `ns_env()` when
  inspecting another package's code from tooling.
- `env_lock()` freezes the container (no add/remove) but existing bindings'
  *values* stay mutable unless you also call `env_binding_lock()`.
- New environments: `env()` inherits from the **current** environment by
  default (good for "a scope extending what I'm in now"); `new_environment()`
  inherits from the **empty** environment by default and takes a list, not
  dots (good for "a standalone container").
- Environments are the mechanism under tidy eval's data masks
  (`eval_tidy()`): a mask is a child environment where `data`'s names
  shadow `env`'s, exactly per `env()`'s child-shadows-parent inheritance
  rule. See `references/environments-deep-dive.md` §8 before mixing
  `env_*` calls with quosures/`eval_tidy()`.

## R execution patterns

Prototype env_* snippets directly: `Rscript -e "library(rlang); <code>"`.
For multi-step explorations, write a throwaway script under the project's
temp/scratch directory and run it with `Rscript path/to/script.R`; clean up
afterward. No package scaffolding needed just to test environment logic.
