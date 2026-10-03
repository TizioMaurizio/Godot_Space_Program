# Restore Codex/project on another Windows PC

The archive is external to Git. Its `manifest.json` identifies the exact handoff commit, both thread IDs, source snapshot, exclusions/redactions, original paths and every payload SHA256. Keep it private: it contains project conversations, even though authentication is excluded.

## What to transfer

Copy **Godot_Space_Program_Codex_Migration_2026-10-03.zip** from `C:\Users\m.vetere\Documents\Codex_Migration_2026-10-03\`. The adjacent `.sha256` file is optional; the checksum is also supplied in the migration response.

Included: sanitized JSONL rollouts for the development and migration threads; project-scoped `state_5.sqlite` and native `thread_history_1.sqlite`; selected index, goals and memory records; referenced pasted text attachments; readable transcripts; full safe source snapshot (tracked and untracked); historical test logs; the existing player craft JSON; restore helper and documentation. Raw user-wide databases are never copied. SQL schemas may include empty unrelated tables, with no user data in them.

Excluded: `auth.json`, `config.toml`, keys/tokens/cookies, SSH material, `.env`, browser/OS credential state, locks, WAL/SHM files, user-wide logs/global state, plugin caches, binaries, engine/templates, `.godot` cache and build outputs. The original files are preserved. There are no credentials supplied for the new PC.

## Restore

Install Git, Python 3.11+ (3.12 recommended), Godot 4.6.1 and a compatible Codex CLI/VS Code extension. Authenticate freshly. Native history was exported from CLI `0.159.0-alpha.12.1`; use a compatible version where possible.

```powershell
Get-FileHash -Algorithm SHA256 'C:\CodexMigration\Godot_Space_Program_Codex_Migration_2026-10-03.zip'
Expand-Archive -LiteralPath 'C:\CodexMigration\Godot_Space_Program_Codex_Migration_2026-10-03.zip' -DestinationPath 'C:\CodexMigration\unpacked'
git clone https://github.com/TizioMaurizio/Godot_Space_Program.git 'C:\Projects\Godot_Space_Program'
$migrationPackage = 'C:\CodexMigration\unpacked\Godot_Space_Program_Codex_Migration'
$migrationManifest = Get-Content -Raw -LiteralPath (Join-Path $migrationPackage 'manifest.json') | ConvertFrom-Json
git -C 'C:\Projects\Godot_Space_Program' checkout $migrationManifest.handoff_commit
python (Join-Path $migrationPackage 'restore_codex_migration.py') --package $migrationPackage
python (Join-Path $migrationPackage 'restore_codex_migration.py') --package $migrationPackage --repo 'C:\Projects\Godot_Space_Program' --restore-workspace
```

The helper verifies all payload hashes and refuses to apply the source snapshot to a dirty checkout or a different commit. It copies captured source files only, never `.git`. The resulting dirty state is intentional: it reproduces the previously uncommitted upgrades and station work. If the handoff commit is already an ancestor of newer work, use a separate clean checkout at the manifest commit to avoid overwriting that newer work.

For history, use a **new dedicated Codex home outside the unpacked package**. Close any clients using that destination first. The helper refuses existing histories, does not copy/read credentials, rewrites only current session metadata/SQLite workspace paths, and recalculates history byte offsets. Historical messages retain old paths.

```powershell
$restoredCodexHome = Join-Path $env:USERPROFILE '.codex-gsp-restored'
python (Join-Path $migrationPackage 'restore_codex_migration.py') --package $migrationPackage --repo 'C:\Projects\Godot_Space_Program' --codex-home $restoredCodexHome --import-history
$env:CODEX_HOME = $restoredCodexHome
codex login
codex resume 01a0ed07-848f-7aa2-8f63-17ad624ae8b6 --cd 'C:\Projects\Godot_Space_Program'
# The separate migration conversation is also available:
codex resume 01a1028b-67de-7e91-a3ab-33639c1abcb1 --cd 'C:\Projects\Godot_Space_Program'
```

The imported history belongs to that `CODEX_HOME`; launch VS Code/Codex from a shell with that variable if using the extension, and restart existing processes first. A running new conversation cannot be transformed into the old conversation merely by importing files. CLI resume is the explicit route; GUI discovery and account/cloud history behavior can differ. Do not overwrite the new PC's main `.codex` or copy the old PC's auth/config to compensate.

Referenced attachment files are available in the restored home's `attachments/` and in the package. Old absolute attachment references remain historical; use those new paths when reading pasted briefs. `AORS_BRIEF.md` is also in Git and the package. Optional player design: copy `godot-user-data/craft/Editor orbital proof.json` to `%APPDATA%\Godot\app_userdata\Godot Space Program\craft\` if it does not overwrite a newer design.

If native resume fails, use `HANDOFF.md`, `AORS_BRIEF.md`, `transcripts/01a0ed07-848f-7aa2-8f63-17ad624ae8b6.md` and the restored working tree. Database/alpha-version compatibility, frontend/account integration, redaction, compaction and the incomplete live migration turn may prevent exact restoration. Do not broaden the export to credentials or unrelated user databases.

Validation on the old PC: all payload hashes and ZIP CRCs checked; fresh project-scoped SQLite databases passed `integrity_check`; the restore helper imported both threads into an isolated home; Codex `0.159.0-alpha.12.1` app-server successfully read both thread summaries and their turn history without authentication. No model inference or old-session resumption was performed. Live processes, pending tool executions and messages written after the snapshot are not transferable; the package records its snapshot time. This confirms local history readability, not a guarantee of GUI/cloud restoration on another version.

Official background: [Codex local state locations](https://learn.chatgpt.com/docs/config-file/config-advanced), [Codex CLI resume](https://learn.chatgpt.com/docs/codex/cli), [app-server thread/history APIs](https://learn.chatgpt.com/docs/app-server). The project-specific export/import is a validated local migration helper, not a guaranteed official cross-PC import feature.

## Exact follow-up prompt

```text
Continue this Godot Space Program project from the old Windows PC. Read docs/CODEX_HANDOFF.md and docs/CODEX_MIGRATION.md. Locate my copied Godot_Space_Program_Codex_Migration_2026-10-03.zip (ask for its location only if you cannot find it), verify its supplied SHA256, extract it outside the repository, and run the included restore helper to verify every manifest hash. In a clean checkout of the manifest's handoff commit, restore the captured workspace so the uncommitted game upgrades and partial station work are preserved; do not reset or overwrite newer work. Import the two project histories into a new dedicated Codex home outside the package, remapping the repository path with the helper, without copying authentication or replacing existing Codex history. Arrange fresh sign-in if needed and give me the exact command to resume development thread 01a0ed07-848f-7aa2-8f63-17ad624ae8b6 with the new checkout. If exact resume is unavailable, continue here using the handoff, docs/AORS_BRIEF.md, referenced pasted attachments and the readable development transcript. Resume the unfinished Aster Orbital Research Station (AORS): reuse existing parts and the S/M/X/XL standardized catalog, complete a playable initialized orbital station with RCS, physical docking/undocking, targeting, vessel switching/persistence and electrical power through the existing spacecraft architecture. Use essential targeted checks and release a Windows build promptly; I accept remaining physics problems and do not want an exhaustive testing campaign before the first station release. Preserve existing work and never commit raw Codex history or secrets.
```
