# llama-swap

A Nix flake that provides [llama-swap](https://github.com/mostlygeek/llama-swap), an OpenAI-compatible proxy that starts and swaps llama.cpp-compatible backends on demand. It carries two additions. Ready-only forwarding of upstream observability endpoints lets a scraper read a loaded backend's metrics without waking a model. A per-model concurrency limit sized by the priority each request states stops low-urgency work shedding urgent work.

## Outputs

- `packages.<system>.llama-swap` — nixpkgs' minimal llama-swap package with both additions applied, providing `bin/llama-swap`. `packages.<system>.default` is the same.
- `checks.<system>.llama-swap` — the same package; building it is the check.

Both are published for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`; there is no `x86_64-darwin` attribute.

```sh
nix build .#llama-swap
```

The package is the **minimal** variant: it carries no embedded web UI, and it bundles no model server — llama-swap launches whatever backends its configuration names, so those must be reachable from it at runtime.

## Observability forwarding

Set the paths you want forwarded in llama-swap's own configuration:

```yaml
upstream:
  observabilityPaths: [/metrics, /health]
```

It is an exact-path list, empty by default. A GET or HEAD to `/upstream/<model>/<path>` whose path matches exactly keeps its configured authentication and bypasses local model admission, but only while that model's backend is ready. An unloaded or not-yet-ready model answers `409` without starting or swapping anything; a backend that stops between that check and the forward answers `503` and the request never reaches it. Every other method and path keeps normal admission behaviour, and query parameters do not change path matching.

Observations are not treated as use: they neither refresh the model's idle timer nor mark it in-flight, so scraping cannot keep a model warm or hold it against a swap. A concurrent stop may interrupt an in-progress observation.

llama-swap's own `/health` endpoint is unchanged — it reports the proxy's liveness, not backend readiness, and an upstream backend's health response describes the loaded model, not whether an idle one could start.

## Priority-shaped concurrency limit

A model caps its in-flight requests at `concurrencyLimit`, counted without regard to what any of them are for: a flood of low-urgency work fills the cap and sheds the urgent request that arrives next. `priorityConcurrencyLimit` replaces that test for one model:

```yaml
models:
  qwen-32b:
    priorityConcurrencyLimit: 24
```

A request states its urgency in the `priority` field of its JSON body, using vLLM's convention: lower is more urgent, and a request stating none is 0. The model admits a request at priority `p` when fewer than `priorityConcurrencyLimit` requests are in flight at priority `p` or lower. Traffic less urgent than `p` never blocks it. One priority level can use the whole cap on its own, so total in flight can exceed it. At the limit above, 24 requests at priority 0 block a 25th at priority 0 and one at priority 50, and admit one at priority -1.

In flight means admitted and not yet finished: queued, waiting on a model swap, or being served. Priority is read after request filters run, so a `setParams` stamp decides both admission and the value the backend receives. Pair the option with a vLLM backend started with `--scheduling-policy priority`.

A priority that is absent, non-integer, or carried in a form instead of a JSON body counts as 0. A negative priority is more urgent than 0. Rejection is the same HTTP 429 with `Retry-After: 1` that `concurrencyLimit` produces.

Leave the option unset or 0 and the model keeps flat `concurrencyLimit` behaviour. Set both, and `priorityConcurrencyLimit` governs.

See [LICENSE.md](LICENSE.md) for licensing and copyright, and [NOTICE.md](NOTICE.md) for the terms of upstream and distributed artifacts.
