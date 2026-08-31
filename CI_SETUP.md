# WARDKEEP CI Setup

## What this gives you

Push to `main` on GitHub:

1. **`build-test-apk`** runs immediately, no approval needed. It exports a
   debug-signed APK (Godot's built-in debug keystore, no secrets required)
   and attaches it to a **pre-release** GitHub Release tagged
   `test-<run number>`. Download the APK from that release, sideload it on
   a device, and test.
2. **`build-release-aab`** is queued but **paused**, waiting on the
   `play-release` GitHub Environment's required-reviewer approval. Nothing
   in this job runs — not even checkout — until you approve it.
3. You approve it (GitHub repo → Actions tab → the pending workflow run →
   "Review deployments" → approve). Only then does it decode your release
   keystore, build the signed `.aab`, and attach it to a full GitHub Release
   tagged `release-<run number>`.
4. Download the `.aab` from that release and upload it to Play Console
   yourself (still a manual upload — Play Console publishing itself is not
   automated here; see note at the end on why).

## One-time setup

### 1. Add the workflow and export presets to the repo

Copy `.github/workflows/android-build.yml` and `export_presets.cfg` from
this bundle into your WARDKEEP repo root, commit, push.

**Until you do steps 2 and 3, the release AAB job is skipped**, not run: the
test-APK job reports whether `ANDROID_KEYSTORE_BASE64` exists and the release
job is conditional on it. That keeps a push to `main` green while release
signing is still unconfigured. Note also that the approval gate is the
*environment*, not the workflow file — a job naming an environment that does
not exist is **not** gated, it simply runs.

### 2. Create the approval-gated environment

GitHub repo → **Settings → Environments → New environment** → name it
exactly `play-release` (the workflow references this name) → under
**Deployment protection rules**, tick **Required reviewers** and add
yourself (or whoever should approve releases). Save.

### 3. Add repository secrets

GitHub repo → **Settings → Secrets and variables → Actions → New repository
secret**. Add all three:

| Secret name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | Your release keystore file, base64-encoded: `base64 -w0 your-release.keystore` (Linux/macOS) — paste the output |
| `ANDROID_KEY_ALIAS` | The key alias inside that keystore |
| `ANDROID_KEY_PASSWORD` | The key/keystore password |

Keep the actual `.keystore` file itself off GitHub entirely — only the
base64 text lives in the secret, and secrets are never printed in logs.

### 4. Pin the Godot version

Edit the `GODOT_VERSION` env var at the top of the workflow and the
`barichello/godot-ci:4.3` image tags (two places) to match whatever Godot
4.x version the project actually uses.

## Version code / version name

`export_presets.cfg`'s `version/code` must increase on every build you
actually intend to upload to Play Console (Google rejects a re-upload with
the same code). Note there are two presets: `Android` builds the release
`.aab` for Play Console, and `Android Test` builds the sideloadable `.apk`
the push-to-main job attaches to a pre-release. They are the same build in
two package formats — an `.aab` cannot be sideloaded, so the test job needs
its own preset. Keep `version/code`, `version/name` and the package name in
sync across both. This repo template does not auto-increment it — bump it by
hand as part of the commit that triggers a release build you intend to
ship, or ask for a small workflow addition that auto-increments it from
`github.run_number` if you'd rather not track it manually.

## Why Play Console upload itself isn't automated

Uploading to Play Console can be automated too (via the Google Play
Developer API and a service account, commonly wrapped by tools like
Fastlane's `supply`), but that requires provisioning a Google Cloud service
account with Play Console API access and granting it release permissions —
a meaningfully bigger one-time setup than this repo-secrets flow, and it
means a CI job can push straight to production without a human touching
Play Console at all. Given the solo, low-frequency release cadence this
project is scoped for, stopping at "you get a ready-to-upload .aab" keeps a
human in the loop at the actual publish step. If you want full
upload-to-Play-Console automation later, that's a follow-up addition to
this same workflow, not a rebuild of it.
