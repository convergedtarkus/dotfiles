# smartgorunner

`smartgorunner` is a command runner that runs go specific commands over changed go files.

## What it does

- Finds changed `.go` files from `git diff HEAD`.
- Ignores paths under top-level `vendor/`.
- Finds module roots from `go.mod` files.
- Groups changed files by the deepest matching module.
- Runs a command in each module with either:
  - changed directories (default), or
  - changed files (`--on-files`).

## Quick usage

```bash
go run ./cmd/smartgo -- go test -count=1
go run ./cmd/smartgo --on-files gofmt -w
```