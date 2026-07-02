# Releasing Apace

Apace ships as a Developer ID-signed, notarized DMG. The steps below take a clean
checkout to a distributable build. Nothing here is run automatically — cutting a public
release is a deliberate, manual step.

## 1. Package (no secrets)

```sh
scripts/package.sh
```

Builds a Release, Developer ID-signed, hardened-runtime `Apace.app` and wraps it in
`dist/Apace.dmg`. Verifies the signature and hardened-runtime flag before packaging.

## 2. Notarize (needs an app-specific password)

Notarization requires an Apple ID **app-specific password** (create one at
appleid.apple.com → Sign-In and Security). It is read from the environment and never
written to disk or committed.

```sh
export AC_USERNAME="you@example.com"
export AC_PASSWORD="abcd-efgh-ijkl-mnop"   # app-specific password
export AC_TEAM="BWD692VD35"
scripts/notarize.sh
```

This submits the DMG to Apple, waits for the result, and staples the ticket. The
stapled `dist/Apace.dmg` is what you distribute.

## 3. Publish

Upload the DMG and, once auto-updates land (below), update the appcast. **Publishing is
gated on explicit sign-off** — don't push a release tag or upload publicly without it.

## Still to wire: auto-updates (Sparkle)

Auto-updates aren't integrated yet. The plan:

1. Add the Sparkle Swift package and an `SPUStandardUpdaterController`, plus a
   "Check for Updates…" menu item.
2. Generate an EdDSA key pair (`generate_keys`); keep the private key in the login
   Keychain (never in the repo), put the public key in `Info.plist` as `SUPublicEDKey`.
3. Host an `appcast.xml` and set `SUFeedURL`; sign each build's appcast entry.
4. A CI release workflow can then run `package.sh` → `notarize.sh` → sign + publish the
   appcast, triggered by a version tag.

## Secrets

The signing certificate lives in the login Keychain; the notarization password is
supplied per-run via the environment. Neither belongs in this public repo.
