# OHOS 2.0.0 release

- ohpm package: **webnat@2.0.0**. Git tag: **v2.0.0**.
- library/oh-package.json5 and library/src/main/ets/version.ets must match.
- Run the commands below from the webnat-ohos repository root with DevEco / hvigorw / ohpm configured.

## Build-only preparation (does not publish)

```bash
./publish.sh --build-only
```

This verifies contracts, runs the Hypium suite and builds
`library/build/default/outputs/default/library.har`. SDK Previewer tests do not replace real-device tests.

## Publish (maintainer executes this)

```bash
ohpm login
./publish.sh
```

The script tests, rebuilds the HAR, displays the version and asks for explicit confirmation before
`ohpm publish`. Alternatively, after verifying the fresh HAR:

```bash
ohpm publish library/build/default/outputs/default/library.har
```

Your account must have package publication permission and the registry's required signature/configuration.
Do not reuse a stale 1.4.0 HAR. Versions are immutable; confirm a previous upload did not succeed before retrying.
Upgrade the Web SDK together; nested undefined / class objects / Date / Map are no longer accepted as data.
