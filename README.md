# llama-swap

A Nix flake that provides [llama-swap](https://github.com/mostlygeek/llama-swap), an OpenAI-compatible proxy that starts and swaps llama.cpp-compatible backends on demand, with one addition: ready-only forwarding of upstream observability endpoints, so a scraper can read a loaded backend's metrics without waking a model.

## Outputs

- `packages.<system>.llama-swap` — nixpkgs' minimal llama-swap package with the addition applied, providing `bin/llama-swap`. `packages.<system>.default` is the same.
- `checks.<system>.llama-swap` — the same package; building it is the check.

Both are published for `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`; there is no `x86_64-darwin` attribute.

```sh
nix build .#llama-swap
```

The package is the **minimal** variant: it carries no embedded web UI, and it bundles no model server — llama-swap launches whatever backends its configuration names, so those must be reachable from it at runtime.

## The addition

Set the paths you want forwarded in llama-swap's own configuration:

```yaml
upstream:
  observabilityPaths: [/metrics, /health]
```

It is an exact-path list, empty by default. A GET or HEAD to `/upstream/<model>/<path>` whose path matches exactly keeps its configured authentication and bypasses local model admission, but only while that model's backend is ready. An unloaded or not-yet-ready model answers `409` without starting or swapping anything; a backend that stops between that check and the forward answers `503` and the request never reaches it. Every other method and path keeps normal admission behaviour, and query parameters do not change path matching.

Observations are not treated as use: they neither refresh the model's idle timer nor mark it in-flight, so scraping cannot keep a model warm or hold it against a swap. A concurrent stop may interrupt an in-progress observation.

llama-swap's own `/health` endpoint is unchanged — it reports the proxy's liveness, not backend readiness, and an upstream backend's health response describes the loaded model, not whether an idle one could start.

See [LICENSE.md](LICENSE.md) for licensing and copyright, and [NOTICE.md](NOTICE.md) for the terms of upstream and distributed artifacts.
