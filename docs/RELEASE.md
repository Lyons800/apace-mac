# Releasing Apace

Apace ships as a Developer ID-signed, notarized DMG with Sparkle auto-updates. There are
two ways to cut a release: **manual** (one-time, on your Mac) and **CI** (push a tag).
Publishing is always deliberate.

## One-time setup

### 1. Sparkle key pair

Generate the EdDSA key pair once (the private key never enters the repo):

```sh
# generate_keys ships in the Sparkle release tarball (github.com/sparkle-project/Sparkle)
./bin/generate_keys
```

- Put the **public** key in `project.yml` → `SPARKLE_PUBLIC_ED_KEY` and commit it (public is fine).
- Keep the **private** key in your login Keychain (generate_keys stores it) and add it as the
  `SPARKLE_PRIVATE_KEY` GitHub secret for CI. Never commit it.

### 2. GitHub secrets (for the release workflow)

Add these in the repo → Settings → Secrets and variables → Actions:

| Secret | What |
|---|---|
| `DEVELOPER_ID_P12` | base64 of your exported "Developer ID Application" cert (`.p12`) |
| `DEVELOPER_ID_P12_PASSWORD` | the `.p12` export password |
| `KEYCHAIN_PASSWORD` | any string — a throwaway password for the CI keychain |
| `NOTARY_APPLE_ID` | your Apple ID (e.g. `oisinlyons13@gmail.com`) |
| `NOTARY_PASSWORD` | an Apple **app-specific password** (appleid.apple.com) |
| `NOTARY_TEAM` | `BWD692VD35` |
| `SPARKLE_PRIVATE_KEY` | the Sparkle EdDSA private key |

## Manual release (on your Mac)

```sh
scripts/package.sh                                   # build + sign + DMG
export AC_USERNAME="you@example.com"
export AC_PASSWORD="abcd-efgh-ijkl-mnop"             # app-specific password
export AC_TEAM="BWD692VD35"
scripts/notarize.sh                                  # notarize + staple
export SPARKLE_PRIVATE_KEY="<private key>"
scripts/appcast.sh v0.1.0                            # sign update + appcast
```

Then create a GitHub Release for the tag and upload `dist/Apace.dmg` + `dist/appcast.xml`.

## CI release (recommended, repeatable)

With the secrets above set, just push a version tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

`.github/workflows/release.yml` then builds, signs, notarizes, staples, signs the update,
builds the appcast, and publishes a GitHub Release with `Apace.dmg` + `appcast.xml`.
`SUFeedURL` already points at `releases/latest/download/appcast.xml`, so shipped apps see
the update automatically.

## Secrets

The signing cert lives in the login Keychain (or a GitHub secret for CI); the notarization
and Sparkle private keys are supplied per-run via the environment / GitHub secrets. None of
them belong in this public repo.
