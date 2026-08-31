# Known issue: the Android export step fails in CI

**Status:** the `test` job is green and gating every push. The
`build-test-apk` job fails at the Godot export step. The game code is fine —
this is packaging.

Godot reports:

```
ERROR: Cannot export project with preset "Android Test" due to configuration errors:

   at: _fs_changed (editor/editor_node.cpp:1012)
```

The message after the colon is **empty**. Godot enumerates this class of
failure verbatim when it can (runs 1 and 2 listed three named errors), so an
empty list means a check failed without contributing text — there is nothing
in the log to act on.

## What has been eliminated

Each of these was ruled out by evidence, not by reasoning:

| Suspect | How it was ruled out |
|---|---|
| Debug keystore, Java SDK path, build template | Named errors in run 1; all three cleared in run 2 and never returned |
| Godot reading the wrong editor settings | Root cause of run 1. GitHub Actions sets `HOME=/github/home` in a container, so Godot never read the settings the image wrote to `/root`. Confirmed by run 4: the keystore path it reports is under `/github/home` |
| Wrong editor-settings filename | Verified locally: 4.3 reads `editor_settings-4.3.tres`, not `editor_settings-4.tres`, and merges a minimal file with its defaults |
| AAB/APK format mismatch | Real defect, fixed in run 3. The `Android` preset is `export_format=1`; the test job writes `.apk`. Now has its own `Android Test` preset |
| Preset options | Reproduced locally, then bisected: a **minimal two-line preset** fails identically. Not `screen/orientation`, not `package/signed`, not the version fields |
| The project itself | A **bare empty Godot project** fails identically with the same preset |
| Signing | `package/signed=false` fails identically |
| Gradle build | `use_gradle_build=false` fails identically |
| Build template not installed | Run 3 diagnostics: `android/.build_version` present, `android/build/` fully populated (build.gradle, gradlew, res, src, libs) |
| Export templates missing | Present in every run: `~/.local/share/godot/export_templates/4.3.stable` |
| SDK platform / build-tools too old | The original theory, now disproved **twice**. Run 5 shows build-tools `33.0.2 34.0.0` and platforms `android-33 android-34` installed, JDK `17.0.12` — and the export still fails. Reproduced the same negative result locally |

## Why it was not diagnosed here

The session that built this had no way to close the last gap:

- Google's SDK repository is unreachable from that network, so a **real**
  Android SDK could not be installed locally. A hand-built SDK of stub
  binaries reproduces the same empty error, but for its own reasons — so the
  local repro cannot discriminate between causes.
- Container registries are likewise unreachable, so the `barichello/godot-ci:4.3`
  image could not be inspected directly.

## The fastest way to finish this

On any machine with a real Android SDK and Godot 4.3:

```bash
godot --headless --path . --install-android-build-template \
  --export-debug "Android Test" build/test/wardkeep-test.apk
```

If it exports cleanly there, the cause is specific to the CI image, and the
answer is a different base image rather than more workflow changes. If it
reproduces, the export runs under a debugger or a Godot build with the
validation branch instrumented — `EditorExportPlatformAndroid::has_valid_export_configuration`
and `has_valid_project_configuration` are where the empty string comes from.

Everything the workflow does to prepare the toolchain is correct and worth
keeping either way: it is only the final export call that fails.
