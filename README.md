# jekyll-agent-markdown

Export Jekyll posts as raw Markdown next to their normal HTML output, and publish a small `llms.txt` index.

## Installation

Add the gem to your site's `Gemfile` plugin group:

```ruby
group :jekyll_plugins do
  gem "jekyll-agent-markdown"
end
```

Then run `bundle install` and enable it in `_config.yml`:

```yaml
plugins:
  - jekyll-agent-markdown
```

## Configuration

Both exports are enabled by default:

```yaml
agent_markdown:
  posts: true
  llms_txt: true
  sort: desc
  include_dates: true
```

`posts`, `llms_txt`, and `include_dates` accept `true`, `false`, or one of the false-style strings `"false"`, `"no"`, and `"off"` (case-insensitively). `sort` accepts `asc` or `desc` and defaults to `desc`, ordering the `llms.txt` article list by normalized published date. Posts with a missing, incomplete, or invalid published date are listed last in their existing order. Unknown keys and other values stop the build with a configuration error instead of being silently ignored. An explicit per-post `agent_markdown` value follows the boolean-setting rules, so a mistyped opt-out cannot publish raw source by accident.

Set `url` to your site's absolute HTTP(S) URL; the `llms.txt` index uses it to generate absolute article links:

```yaml
url: https://example.com
```

When `url` is missing, contains credentials, a query, or a fragment, or is not an absolute HTTP(S) URL, `llms.txt` is skipped with a warning and the rest of the build continues. The build only fails when you set `llms_txt` explicitly in `_config.yml`, since that states clear intent.

Set `agent_markdown: false` to disable both exports, or `agent_markdown: true` to enable both explicitly (same as leaving it unset). The strings `"false"`, `"no"`, and `"off"` are also treated as false, case-insensitively.

Markdown sibling paths are deterministic:

| Post URL | Markdown URL |
|---|---|
| `/foo/` | `/foo.md` |
| `/foo.html`, `/foo.htm` | `/foo.md` |
| `/foo.html/` | `/foo.html.md` |
| `/foo/index.html` | `/foo.md` |
| `/foo` | `/foo.md` |
| `/` | `/index.md` |

Extensions are matched case-insensitively, and percent-encoded aliases are compared by their final decoded destination. Destination ownership also treats case-only and Unicode-normalization aliases as equivalent on every platform, keeping builds portable across filesystems. File-versus-directory conflicts are reserved as well. Before adding an export, the plugin checks every page, static file, and writable collection document already known to Jekyll. The existing destination owner wins; later post exports are skipped with a warning and omitted from `llms.txt`. A committed `llms.txt` wins in the same way.

The generated file preserves the post's original Markdown body as its initial content, with no front matter, HTML conversion, or Liquid rendering. Liquid tags and directives such as `{{ site.title }}` are published literally. By default, the plugin appends the post's published `date` and optional `last_modified_at` value as a small footer:

```text
---
Published at: 2026-01-01 | Updated at: 2026-02-03
```

Each available date is formatted as `YYYY-MM-DD`. String values must contain an explicit year, month, and day; missing, incomplete, and invalid values and their labels are omitted. An empty post contains only the metadata line, without a leading `---` that could be mistaken for front matter. Set `include_dates: false` to omit date metadata from both Markdown exports and `llms.txt`, leaving the body-only export shape used before date metadata was introduced.

Exclude one post with front matter:

```yaml
agent_markdown: false
```

Expose the alternate representation from a layout:

```liquid
{% if page.agent_markdown_url %}
  <link rel="alternate" type="text/markdown" href="{{ page.agent_markdown_url | relative_url }}">
{% endif %}
```

The conditional omits the link for opted-out and colliding posts. The `relative_url` filter adds `baseurl` for sites deployed below the domain root.

The generated `/llms.txt` is a compact index, for example:

```text
# Example Site

> A short description

## Articles

> Posts only. Pages and collections are not included.

- [First article](https://example.com/articles/first.md) | Published at: 2026-01-01
```

## Deployment notes

Configure your host to serve generated `.md` files as `Content-Type: text/markdown; charset=utf-8` and, when appropriate, `X-Robots-Tag: noindex`. This gem writes files only; it cannot set HTTP response headers. Generated files refuse to write through symlinks inside the destination. GitHub Pages safe mode may not run arbitrary plugins, so use a separate build/deploy pipeline there.

## v0.1.0 limitations

Only posts are exported. Pages and custom collections, custom Markdown transformations or templates, front-matter allowlisting, automatic response headers, sitemaps, and richer article metadata are intentionally deferred.

## Development

Run `bundle exec rake` after `bundle install` to execute both Minitest and RuboCop.

The entry point explicitly loads the plugin's small implementation tree without an additional runtime loader dependency. Implementation files also declare their own prerequisites so public constants can be required directly in isolation.

## License

Apache License 2.0.
