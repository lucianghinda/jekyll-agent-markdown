# llms.txt Author Design

## Goal

Include the blog author's name in generated `llms.txt` files by default, with an explicit opt-out.

## Configuration

Add `agent_markdown.include_author`. It uses the existing boolean-setting rules and defaults to `true` when omitted. Setting it to `false` or a supported false-style string omits author metadata.

## Author resolution and output

Read the site-wide Jekyll `author` setting through a focused llms.txt heading formatter. A scalar value is the author name; a mapping uses its `name` value. Missing, false, empty, or nameless mappings produce no author line. Normalize whitespace so configuration cannot inject extra Markdown lines.

When enabled and a name is available, add `Author: <name>` after the optional site-description blockquote and before `## Articles`. This is a non-heading detail paragraph allowed by the llms.txt format and does not change post Markdown exports.

## Verification

Tests cover the default-on scalar author, mapping-form author, explicit opt-out, missing author, whitespace normalization, false-style opt-out, and invalid option validation. Existing generation, configuration, lint, and package tests must remain green.
