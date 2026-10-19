# Flashable device images

Three layers, each a build:

1. **Image base** (once per machine and meta-pantavisor version, Yocto,
   ~hours cold): meta-pantavisor with kas files, e.g. for Raspberry Pi
   (incl. CM5):
   `pvr build start --project cm5 --target image-base --git-url https://github.com/pantavisor/meta-pantavisor --git-ref <tag> --image-base kas/machines/rpi.yaml,kas/scarthgap.yaml,kas/bsp-base.yaml,kas/build-configs/build-image-base.yaml --platform linux/arm64 --limit-seconds 14400`
2. **Factory** (per base × signing identity × policy, minutes, no secrets):
   `pvr build start --project cm5 --target image --base <base id> --identity acme --policy green --policy red --make-factory --limit-seconds 3600`
   Optional `--group-timeout NAME=SECONDS` (e.g. `root=120`) when the BSP's
   container groups need longer to start.
3. **Images** (per release, seconds):
   `pvr build start --project cm5 --target image --factory <factory id> --identity acme --policy green --app-build <app build id> --oem oem.json`
   Gives `<identity>-<policy>.img.xz` per policy. Images carry join tokens:
   treat them as secrets and share download links only with whoever flashes.

The identity needs a platform key (`pvr signing create acme --platform`).
Apps that go into the image must be signed with `acme-oem`.

## OEM configuration part

`oem.json` adds `<identity>/<policy>.config`, signed with the platform key;
the image's `PV_POLICY` picks the file. Values are literals or config
secrets by name, never pasted tokens:

```json
{
  "name": "acme",
  "signing_secret": "acme-platform",
  "configs": {
    "green": {
      "PH_CREDS_HOST": "<api host, e.g. api.pantahub.com>",
      "PH_FACTORY_AUTOTOK": { "secret": "acme-green-autotok" }
    }
  }
}
```

- `PH_FACTORY_AUTOTOK` is a device join (auto-join) token the user creates
  in the web app (Device Tokens) and stores as a config secret.
- `PH_CREDS_HOST` decides which Hub the devices join; when every policy sets
  it, the image's `pantahub.config` follows it.
- `pvr build start ... --oem oem.json` works on app builds too (the part
  travels in the app's export).

## Flash and first boot

- SD card: `bmaptool copy acme-green.img.xz /dev/sdX` or Raspberry Pi
  Imager. CM5 eMMC: USB boot mode, `rpiboot`, then write the image.
- Wi-Fi on a Pi without Ethernet: `pvr wifi device-scan`, then the user runs
  `pvr wifi provision <mac> --ssid … --password …` themselves.
- The device boots revision 0, joins the token's account, and appears in
  `list_devices` / the web app.

## MQTT management agent (pv-mqtt-sdk)

Replaces Pantavisor's own Hub client (updates pushed over MQTT, live logs,
web SSH). It is **not open source**: its source is not public and it can't
be built from a repository. Pantacor ships it as prebuilt pvr exports per
device on https://pantavisor.io/downloads/ — the user downloads the one for
their device, then it is deployed like any export (`pvr merge` of the file,
or `get_export_upload_link` / `import_export_from_url` and `plan_revision`
with `import_export`).

- It only runs where Pantavisor's own client is off: the device's OEM
  configuration must set `PV_CONTROL_REMOTE=0`, `PV_CONTROL_REMOTE_ALWAYS=0`,
  `PV_LOG_PUSH=0`, `PH_UPDATER_NETWORK_TIMEOUT=600` and `PH_CREDS_HOST`.
- A strict device verifies it like any app: the downloaded export must be
  signed with a key the device trusts. If it isn't, ask the user how they
  get it signed for their identity; don't remove or skip signatures.
- Drop an unsigned `pv-oem-developer-001` part if the export carries one.
- Once running it publishes `pantavisor.sdk.*`, `pantavisor.policy` and
  `pantavisor.oem` device-meta.

## When a new device doesn't come up

Read its logs (or a serial console: `pvr device tty -d /dev/ttyUSB0 log`).
Common causes: signature refused in `strict` (wrong identity or an unsigned
part), a container group timing out (`--group-timeout`), a wrong Hub host,
or an expired/disabled join token.
