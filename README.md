# helium-wv-flake

Linux-only Nix flake for [Helium](https://helium.computer/) with bundled Widevine support.

This flake:

- packages Helium for `x86_64-linux` and `aarch64-linux`
- copies `WidevineCdm` into the app bundle
- writes Helium's `latest-component-updated-widevine-cdm` file on launch
- provides an `update.sh` script to refresh upstream version URLs and hashes
- has a GitHub Actions workflow that updates, builds, pushes to Cachix, then pushes `main` and tags

## Use

Run it directly:

```bash
nix run github:jono/helium-wv-flake
```

Build it:

```bash
nix build github:jono/helium-wv-flake
```

Or from this repo:

```bash
nix run .#helium
nix build .#helium
```

## Cachix

Public cache:

```text
https://helium-wv.cachix.org
```

Public signing key:

```text
helium-wv.cachix.org-1:vLs25jjZRJseo0XyIHZ4lucNrKAskY9hcmixywioaio=
```

Temporary use:

```bash
nix build .#helium \
  --option substituters "https://cache.nixos.org https://helium-wv.cachix.org" \
  --option trusted-public-keys "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= helium-wv.cachix.org-1:vLs25jjZRJseo0XyIHZ4lucNrKAskY9hcmixywioaio="
```

Persistent Nix config:

```conf
substituters = https://cache.nixos.org https://helium-wv.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= helium-wv.cachix.org-1:vLs25jjZRJseo0XyIHZ4lucNrKAskY9hcmixywioaio=
```

## Updating

Refresh the packaged release metadata:

```bash
./update.sh
```

`update.sh`:

- fetches the latest Helium Linux release from GitHub
- respects `GITHUB_TOKEN` if set
- prefetches the release assets with `nix-prefetch-url`
- rewrites `versions.json`

If you also want to refresh flake inputs:

```bash
nix flake update
```

## Development

Enter the dev shell:

```bash
nix develop
```

Current dev shell tools:

- `jq`
- the packaged `helium`
