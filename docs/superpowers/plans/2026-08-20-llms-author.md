# llms.txt Author Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Include the Jekyll site's author name in generated `llms.txt` by default and allow sites to opt out.

**Architecture:** Extend the existing normalized boolean settings with `include_author`. Format llms.txt site headings in a focused object that accepts either a scalar `author` value or a mapping with `name`, then place the normalized author detail before the article section.

**Tech Stack:** Ruby 3.2+, Jekyll 4.3–4.4, Minitest, RuboCop

---

### Task 1: Lock author output and configuration behavior

**Files:**
- Modify: `test/jekyll/agent_markdown_test.rb`

- [x] **Step 1: Add the default author fixture and exact-output expectation**

Add `"author" => "Example Author"` to `base_config`, and include this paragraph in the expected `llms.txt` output before `## Articles`:

```text
Author: Example Author
```

- [x] **Step 2: Add focused behavior tests**

Add Minitest cases proving that `author: { name: "Example\nAuthor" }` becomes `Author: Example Author`, `include_author: false` and `include_author: "off"` omit the line, and `author: nil` omits the line without failing.

- [x] **Step 3: Extend invalid-setting validation coverage**

Add `["include_author", 0]` to the invalid nested configuration values so the new option follows existing boolean-setting validation.

- [x] **Step 4: Run the focused tests and verify RED**

Run:

```sh
bundle exec ruby -Itest test/jekyll/agent_markdown_test.rb
```

Expected: failures because the generator does not emit `Author:` and configuration rejects `include_author` as unknown.

### Task 2: Implement the default-on author detail

**Files:**
- Modify: `lib/jekyll/agent_markdown/configuration.rb`
- Modify: `lib/jekyll/agent_markdown/generator.rb`
- Create: `lib/jekyll/agent_markdown/llms_headings.rb`
- Modify: `test/jekyll/load_order_test.rb`
- Modify: `test/package_test.rb`

- [x] **Step 1: Allow the new boolean setting**

Add `include_author` to `Configuration::ALLOWED_SETTINGS`. The existing `enabled?` method supplies the required `true` default and existing validation accepts booleans and supported false-style strings.

- [x] **Step 2: Pass settings into heading generation**

Change `llms_txt` to call `LlmsHeadings.new(site, settings).to_s`, require the new implementation file, and cover it in load-order and package tests.

- [x] **Step 3: Resolve and append the author name**

In `LlmsHeadings`, when `Configuration.enabled?(settings, "include_author")` is true, resolve a scalar author directly or a mapping's string/symbol `name`, normalize it with `one_line`, and append `Author: <name>` only when non-empty.

- [x] **Step 4: Run the focused tests and verify GREEN**

Run:

```sh
bundle exec ruby -Itest test/jekyll/agent_markdown_test.rb
```

Expected: all generator tests pass.

### Task 3: Document and verify the feature

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

- [x] **Step 1: Document configuration and supported author shapes**

Add `include_author: true` to the configuration sample, include it in the boolean-setting rules, and explain that author output reads either `author: Name` or `author: { name: Name }` and may be disabled with `include_author: false`.

- [x] **Step 2: Update the generated-output example and changelog**

Add `Author: Example Author` before `## Articles` in the README example and add an Unreleased changelog entry describing the default-on author metadata and opt-out.

- [x] **Step 3: Run full verification**

Run:

```sh
bundle exec rake
```

Expected: the complete Minitest suite and RuboCop pass with no errors.
