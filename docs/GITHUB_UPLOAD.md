# GitHub Upload Notes

## Current Local State

At the time this document was created:

- `D:\GISS` was not yet a Git repository.
- No GitHub remote was configured.
- `gh` GitHub CLI was not installed on the Windows PATH.
- Codex had a GitHub connector capable of writing text files to an existing repository if given `owner/name`.

## Recommended GitHub Strategy

Do commit:

- `README.md`
- `.gitignore`
- `docs/`
- `scripts/`
- `services/`
- `web/index.html`
- `web/src/`
- `web/config/`
- `tests/`
- `services/tools/` build/test Dockerfiles
- root `*.cmd` launchers

Do not commit:

- `raw/`
- `products/`
- `tmp/`
- `runtime/`
- `web/assets/glyphs/`
- `web/assets/sprites/`
- `web/vendor/`
- Docker volumes
- `services/.env`
- `data/media/`, `data/exports/`, and backups

These ignored files are reproducible from scripts.

## Local Git Init

```powershell
cd D:\GISS
git init
git add README.md .gitignore docs scripts services tests web/index.html web/src web/config *.cmd
git commit -m "Build local-first Jiangsu Anhui GIS MVP"
```

If Git is not on PATH, use the Git bundled with Codex or install Git for Windows.

## Push to a New GitHub Repository

Create a GitHub repository first, for example:

```text
<owner>/giss-offline-map-mvp
```

Then:

```powershell
git remote add origin https://github.com/<owner>/giss-offline-map-mvp.git
git branch -M main
git push -u origin main
```

## Upload Through Codex GitHub Connector

If using the connector instead of local `git push`, provide the target repository in this form:

```text
owner/repo
```

Then the text files can be uploaded through GitHub's contents API. Binary/generated assets should still be rebuilt by scripts instead of uploaded one by one.
