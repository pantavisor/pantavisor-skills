# pvr: builds and deploys from a terminal

Every `pvr build` command prints JSON; pipe it to `jq`. Use a pvr whose
`pvr --help` lists `build`, `secret` and `signing`.

## Log in (once)

```sh
export PVR_BASEURL=<api>                 # or pass -b <api> to each command
pvr login <api>/auth/auth_status         # the user signs in
```

If a command answers 401, ask the user to log in again; don't handle their
password.

## Start a build

```sh
# repository with a Dockerfile or pvpkg.json
ID=$(pvr build start --project my-app \
  --git-url https://github.com/acme/my-app --git-ref main \
  --platform arm64 --limit-seconds 1800 | jq -r .id)

# several architectures: a pipeline, one export each
pvr build start ... --platform arm64,amd64

# registry image pinned by digest
pvr build start --mode docker --project nginx \
  --image docker.io/library/nginx@sha256:<digest> --platform arm64 --limit-seconds 900
```

Useful options: `--context DIR` (where pvpkg.json/Dockerfile live),
`--dockerfile PATH`, `--app NAME` (container name), `--secret NAME` (git
secret; naming it also lets Yocto/Buildroot recipes fetch private sources),
`--signing-secret <identity>-oem`, `--oem oem.json` (OEM configuration
part, see images.md), `--idempotency-key KEY` (re-sending returns the same
build).

## Follow it

```sh
pvr build status $ID | jq '{status, phase}'
pvr build logs $ID | jq -r '.logs[].message' | tail -50
while :; do s=$(pvr build status $ID | jq -r .status)
  case $s in succeeded|failed|cancelled|timed_out) echo $s; break;; esac; sleep 20; done
pvr build cancel $ID
pvr build list --project my-app
pvr build usage
```

## Download

```sh
pvr build download $ID                       # sha256-checked, never overwrites
pvr build download --platform arm64 $ID      # one architecture of a pipeline
pvr build download --name acme-green.img.xz $ID
```

## Deploy to a device

```sh
pvr clone <user-nick>/<device-nick> dev && cd dev
pvr merge ../my-app.pvrexport.tgz      # adds the export's parts, keeps the rest
rm -rf pv-oem-developer-001            # only if present and the device is strict
pvr checkout && pvr add .
pvr status; pvr diff                   # show the user, get a yes
pvr commit -m "my-app 1.2.0" && pvr post -m "my-app 1.2.0"
```

Then watch the revision on the device page, or with the MCP
`get_device_status` / `get_device_logs` if the connector is set up.

## Secrets and signing (the user types the values)

```sh
pvr secret ls
pvr secret add --type git --host github.com/acme gh-acme        # value via stdin/prompt
pvr secret add --type config --host github.com/acme green-autotok
pvr secret add --type git --host github.com/acme --ref tags/v* release-git
pvr signing ls
pvr signing create acme --platform       # Hub-made OEM + platform keys
pvr signing trust acme -o trust/         # root certs an image needs
```

Let the user run `secret add` and `pvr wifi provision` themselves (in
Claude Code they can prefix a command with `!` to run it in the session):
the value is typed at their prompt, never into a command you write.
