## [0.4.0] - 2026-08-25

- Export Markdown-backed pages and selected output collections alongside posts.
- Add per-document export, index, section, optional, and document-header settings.
- Curate `llms.txt` with sections and descriptions, and add optional `llms-full.txt` output.
- Register `{% agent_markdown_link %}` and expose `agent_markdown_url` for custom layouts.
- Package Cloudflare Workers, Netlify Edge, and nginx+njs negotiation recipes.
- Preserve existing posts-only defaults, collision handling, raw Markdown, and metadata output.

## [0.3.1] - 2026-08-20

- Include the site author in each exported article's metadata footer on the same line as published and updated dates.

## [0.3.0] - 2026-08-20

- Include the site author's name in `llms.txt` by default, with an `include_author` opt-out.

## [0.2.0] - 2026-08-20

- Add configurable `llms.txt` ordering by normalized published date, defaulting to newest first and placing missing or invalid dates last.
- Include available published and updated dates in `llms.txt` and Markdown exports by default, with an `include_dates` opt-out.

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
