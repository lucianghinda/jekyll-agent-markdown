# jekyll-agent-markdown

Export Jekyll content as Markdown siblings and curated `llms.txt` and `llms-full.txt` indexes.

AI agents and LLM crawlers read Markdown better than rendered HTML.
This plugin publishes a Markdown copy of each exported post, page, and collection document next to its HTML.
It also writes the index files described by the [llms.txt convention](https://llmstxt.org).

## Installation

Add the gem to your site's `Gemfile`.

```ruby
group :jekyll_plugins do
  gem "jekyll-agent-markdown"
end
```

Install dependencies.

```sh
bundle install
```

The `:jekyll_plugins` group already enables the plugin.
If you keep the gem outside that group, list it under `plugins:` instead.

```yaml
plugins:
  - jekyll-agent-markdown
```

## Quick Start

Configure the sources you want and build the site.

```yaml
url: https://example.com
collections:
  guides:
    output: true
agent_markdown:
  pages: true
  collections:
    - guides
```

```sh
bundle exec jekyll build
```

The build now writes:

- `/llms.txt`, an index of the exported documents
- a Markdown sibling for every post, Markdown page, and `guides` document, such as `/guides/start.md` next to `/guides/start/`

## Usage

Enable the sources you want.

- Posts export by default.
- Markdown-backed pages need `pages: true`.
- Markdown collection documents need `collections` and `output: true`.
- Non-Markdown pages, non-Markdown collection documents, and generated pages are ignored.
- A missing or non-output collection fails the build.
- A selected collection with a Markdown document lacking a public document URL fails.
- The reserved `posts` collection cannot appear in `collections`.

Use site-level `agent_markdown: true` to enable the defaults.
Use site-level `agent_markdown: false` to disable every export.
Boolean settings accept `true` and `false` scalars.
They also accept `"false"`, `"no"`, and `"off"` as false.
False-style strings are case-insensitive and work in front matter.
Unknown keys, wrong types, and invalid combinations fail the build.
Duplicate collection names also fail the build.

Markdown siblings follow the permalink.

| Post URL | Markdown URL |
| --- | --- |
| `/foo/` | `/foo.md` |
| `/foo.html`, `/foo.htm` | `/foo.md` |
| `/foo.html/` | `/foo.html.md` |
| `/foo/index.html` | `/foo.md` |
| `/foo` | `/foo.md` |
| `/` | `/index.md` |

Each post export ends with a metadata footer built from the available dates and the site author.
Disable it with `include_dates: false` and `include_author: false`.

```text
Post body.

---
Published at: 2026-01-01 | Updated at: 2026-01-05 | Author: Example Author
```

Set per-document settings in front matter.

```yaml
agent_markdown: false
```

```yaml
agent_markdown:
  export: true
  index: true
  section: Documentation
  optional: false
  include_document_header: true
```

Use `optional: true` without `section` for the `Optional` section.
Front matter cannot enable a globally excluded source kind.
`export: false` also disables `index`.
Do not combine `export: false` with `index: true`.
Do not combine `optional: true` with `section`.

Add `include_document_header: true` to prepend a small header.
That setting needs a valid absolute `url`.
A valid `url` uses HTTP(S) without credentials, a query, or a fragment.

The header holds the title, the front matter description when present, and a `Source:` link to the HTML page.
The body below the divider stays untouched.

```markdown
# About this site

A one-line description from front matter

Source: https://example.com/about/

---

## What we do

Raw page body.
```

Use `llms_txt: true` for the compact index.
`llms.txt` has two layouts.
With the posts-only defaults it keeps the original single-list layout, byte-for-byte identical with releases before 0.4.0.
Enabling pages, collections, or descriptions, or using `section` or `optional` in front matter, switches to the sectioned layout shown below.

Add `include_descriptions: true` for sanitized descriptions.
Descriptions fall back to the document excerpt.
Use `sort: asc` or `sort: desc` for each section.
Set `include_author: false` or `include_dates: false` to trim metadata.
Mark a document `optional: true` to move it under `Optional`.
Default sections appear before custom sections.
Custom sections keep their first-occurrence order.
The `Optional` section always appears last.

```text
# Example Site

> A short description

Author: Example Author

## Articles

- [First article](https://example.com/articles/first.md) | Published at: 2026-01-01

## Pages

- [About](https://example.com/about.md): About page

## Guides

- [Getting started](https://example.com/guides/start.md)

## Optional

- [Reference](https://example.com/reference.md)
```

Use `llms_full_txt: true` for the full index.
It uses the same document selection as `llms.txt`.
It still works when `llms_txt: false`.
Each entry expands into a full Markdown document block.
Set `url` to a valid absolute HTTP(S) URL first.
The generator warns once when the rendered file exceeds 1 MiB.

```text
# Example Site

## Articles

### [First article](https://example.com/articles/first.md)

Source: https://example.com/articles/first/

Body of the first article.
```

Add the alternate link from a layout.

```liquid
{% agent_markdown_link %}
```

It renders a discovery link for the current page.

```html
<link rel="alternate" type="text/markdown" href="/about.md">
```

The tag is baseurl-aware.
It is empty for opted-out or collided documents.
Use `page.agent_markdown_url` when custom markup needs the generated path.

On collision, existing destinations win.
Generated claims run through posts, then pages, then configured collections.
Later exports skip with a warning and receive no `agent_markdown_url`.
They are also omitted from both indexes.
A committed `llms.txt` or `llms-full.txt` also wins on collision.
Collision detection only sees files Jekyll knows about when this plugin runs at `priority :low`.
Another plugin generating files at `priority :lowest` runs later and can still claim the same destination.

## Options

Boolean settings accept `true`, `false`, and false-style strings.
Unknown keys and invalid values raise `Jekyll::Errors::FatalException`.

These are the complete defaults.

```yaml
agent_markdown:
  posts: true
  pages: false
  collections: []
  llms_txt: true
  llms_full_txt: false
  include_descriptions: false
  include_document_header: false
  include_author: true
  include_dates: true
  sort: desc
```

| Option | Default | Notes |
| --- | --- | --- |
| `posts` | `true` | Export posts. |
| `pages` | `false` | Export pages. |
| `collections` | `[]` | Export output collections named here. |
| `llms_txt` | `true` | Write `llms.txt`. |
| `llms_full_txt` | `false` | Write `llms-full.txt`. |
| `include_descriptions` | `false` | Append sanitized descriptions to `llms.txt`. |
| `include_document_header` | `false` | Prepend document headers to Markdown exports. |
| `include_author` | `true` | Include author metadata. |
| `include_dates` | `true` | Include published and updated dates. |
| `sort` | `desc` | Order each section by normalized publish date. |

The default `llms_txt` warns and skips when `url` is missing or invalid.
Explicitly configuring `llms_txt` makes an invalid `url` fatal.
`llms_full_txt` needs a valid absolute `url` whenever enabled.
Document headers enforce the same URL rules only when enabled.

## Compatibility

Ruby 3.2 or newer is required.
Jekyll 4.3 or newer is required, but Jekyll 5 is unsupported.
The plugin writes files only.
There is no automatic injection into rendered HTML.
Layouts must invoke `{% agent_markdown_link %}` explicitly.
It does not handle content negotiation; see [examples/](examples/) for Cloudflare Workers, Netlify Edge, and nginx recipes.
It does not generate crawler policy, analytics, middleware, response headers, or crawler permissions.
It publishes raw Markdown without rendering Liquid.
Post exports append enabled date and author metadata.
Document headers prepend content only when enabled.
Destination ownership is normalized across case, Unicode normalization, encoded aliases, and file-versus-directory conflicts.
See the [deployment guide](docs/deployment.md) for host setup.

### Limitations

Page and collection exports require authored Markdown and public URLs.
Generated pages and non-Markdown page or collection sources are ignored.
Raw Liquid may expose source directives to Markdown readers.
GitHub Pages safe mode may require an external build pipeline.

## Development

Run the tests and RuboCop.

```sh
bundle install
bundle exec rake
```

## License

Apache License 2.0.
