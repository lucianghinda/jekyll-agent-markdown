# Article Author Footer Design

## Goal

Include the configured blog author in each exported article's metadata footer and release the behavior as version 0.3.1.

## Output contract

Append `Author: <name>` after available date entries on the existing footer line:

```text
Published at: 2026-01-01 | Updated at: 2026-02-03 | Author: Example Author
```

Use the same scalar or `name`-mapping site author resolution as `llms.txt`. Do not introduce per-post overrides.

## Configuration

The existing `agent_markdown.include_author` setting controls author metadata in both `llms.txt` and article exports and remains enabled when omitted. `include_author` and `include_dates` are independent: either can produce a footer by itself, while disabling both preserves a body-only export. Missing or unusable site author metadata produces no author entry.

## Architecture

Extract site-author normalization into a shared formatter used by the llms.txt headings and article generation. Compose article footer entries in a focused footer formatter so date metadata remains responsible only for dates and all available entries are joined on one line.

## Verification

Regression tests cover default date-and-author output, mapping-form author normalization, author-only and date-only footers, both options disabled, missing authors, empty posts, and the 0.3.1 version. The full test and lint suite must pass.
