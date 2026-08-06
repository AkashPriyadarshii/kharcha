# Kharcha — Troubleshooting / Known Issues

> Environment and tooling gotchas that ate a dev's time. Append when you hit a new one.
> This is not product docs — it's for the two of us, mid-build.

## 1. `flutter test` / `flutter build` crashes on Windows host — sqlite3.dll native-assets

**Symptom (Windows only):**
```
Oops; flutter has exited unexpectedly:
"PathExistsException: Cannot copy file to '...\build\native_assets\windows\sqlite3.dll', path = '...\.dart_tool\hooks_runner\shared\sqlite3\build\download-e6ebc264\sqlite3.dll' (OS Error: Cannot create a file when that file already exists, errno = 183)"
```
Also seen as `PathNotFoundException` (errno 2) after a `flutter clean`.

**Root cause:** Flutter's native-assets step for the host platform collides on `sqlite3.dll`. The `sqlite3` package (pulled by Drift) ships its dll via the native-assets hook into `build\native_assets\windows\`, and the tool's own copy step writes to the **same path** — second write dies. It's a tool bug, not app code. `flutter analyze` still passes clean; the crash is only in the test/build native-assets phase on Windows.

**Impact:** `flutter test` can't run on a Windows host until Flutter fixes it or the dll collision is avoided. Android builds are unaffected (Android is the actual target).

**Things tried (didn't stick):**
- `flutter clean` — re-triggers the hook, same crash.
- Delete `build\native_assets\` + `.dart_tool\hooks_runner\shared\` — hook re-downloads, tool still double-copies.

**Workarounds / next steps when revisiting:**
1. Upgrade Flutter stable past 3.41.9 — check if the native-assets copy bug is fixed.
2. `flutter test` against an Android device/emulator (integration path) — skips the Windows host dll copy.
3. Investigate whether sqlite3's hook can be told to defer to `sqlite3_flutter_libs` (sqlite3 README: "hook options page": `doc/hook.md`).

**Status:** open. Tests for Step 2.1 are written (`test/transaction_repository_test.dart`, `test/validate_manual_transaction_test.dart`, `test/add_expense_flow_test.dart`) and pass logic-wise; the gate is blocked by this tool bug on Windows. Not a code failure — do not "fix" the tests to work around it.
