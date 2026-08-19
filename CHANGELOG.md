## [Unreleased]

## [0.1.0] - 2026-08-18

- Export Jekyll posts as raw Markdown siblings.
- Generate an optional `llms.txt` article index.
- Skip `llms.txt` with a warning when `url` is missing; fail only when `llms_txt` is explicitly configured.
- Warn and skip instead of silently overwriting when two posts map to the same Markdown path or the path belongs to an existing file.
- Escape Markdown link syntax in `llms.txt` titles and URLs.
- Compare portable canonical destinations across pages, static files, and collection documents, including encoded, case-only, Unicode-normalization, file-versus-directory, and `/llms.txt` conflicts.
- Preserve raw Liquid in Markdown exports and document baseurl-aware alternate links.
- Reject unsafe destination symlinks, credentialed URLs, and invalid site or per-post configuration values.
- Keep trailing-slash permalink segments ending in `.html` distinct from file-style `.html` permalinks.
- Load the small implementation tree explicitly while keeping implementation files directly requireable.
