# Preparing a repository

The builder fetches the pushed repository at one commit and builds the
**build context** (the root unless `context` names a folder). Every path in
`pvpkg.json` is relative and inside the repository.

## Plain Dockerfile

Any repo with a `Dockerfile` builds as is; the container is named after the
repo or the build's `app`. Keep images small (alpine/distroless), run one
service, log to stdout. For several architectures:

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.24-alpine AS build
ARG TARGETARCH
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 GOARCH=$TARGETARCH go build -o /out/app .

FROM alpine:3.20
COPY --from=build /out/app /usr/bin/app
ENTRYPOINT ["/usr/bin/app"]
```

## pvpkg.json (packaged app)

```json
{
  "name": "my-app",
  "url": "ghcr.io/acme/my-app:main",
  "package_url": "https://github.com/acme/my-app",
  "arch": ["arm64v8", "amd64"],
  "dockerfile": "Dockerfile",
  "src_extra": { "args": { "PV_GROUP": "app" } }
}
```

- `arch`: `amd64`, `arm64v8`, `arm32v6`, `arm32v7`; omit to allow all.
- `version`: else the tag name, or `0.0.0-g<commit>`.
- `src_extra.args`: Pantavisor container args (`PV_GROUP`: `root`,
  `platform`, `app`; `PV_ROLES` such as `mgmt` for a management agent;
  restart policy…). Generated fields (`docker_*`, `rootfs_url`, `pvr`) can't
  be set.
- `pvpkg/generic/…` is laid over every architecture's export,
  `pvpkg/<arch>/…` over one: configuration files go in
  `pvpkg/generic/_config/<app>/<path in container>`. Only directories and
  regular files, no symlinks.

## Yocto (kas)

```json
{
  "name": "hello-http",
  "arch": ["arm64v8"],
  "build": {
    "kind": "yocto",
    "kas": { "arm64v8": "kas-arm64.yml" },
    "target": "hello-http-image",
    "config": { "Entrypoint": ["/usr/bin/hello-http"] },
    "args": "args.json"
  }
}
```

The kas file includes the repo's own layer (a repo entry without `url`) plus
poky, meta-openembedded, meta-virtualization and meta-pantavisor. To build in
minutes, start from meta-pantavisor CI's config for the target (e.g.
`kas/build-configs/release/containers/docker-armv8-scarthgap.yaml`): keep its
machine, distro, layer commits and `local_conf_header`, add only your layer
and change `target`. The log's `Sstate summary` should be above 95%.

## Buildroot

```json
{
  "name": "tiny-app",
  "arch": ["arm64v8"],
  "build": {
    "kind": "buildroot",
    "ref": "2025.02.6",
    "defconfig": "configs/tiny_arm64_defconfig",
    "external": "br2-external",
    "config": { "Entrypoint": ["/usr/bin/tiny-app"] }
  }
}
```

## Private sources

A private repo needs a git secret covering its host/path. A Yocto or
Buildroot recipe fetching private layers or `SRC_URI`s only gets the secret
when the build names it (`--secret` / `secret`).

## Before pushing

`arch` covers the platforms you'll request; kas files, defconfigs and
overlays are committed; no paths with `..` or absolute paths.
