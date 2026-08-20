# Article Author Footer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-ruby:subagent-driven-development (recommended) or superpowers-ruby:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the configured site author to exported article metadata footers and release version 0.3.1.

**Architecture:** Introduce `AuthorMetadata` as the shared site-author formatter for `llms.txt` and articles. Introduce `MetadataFooter` to join enabled entries on one line and append them safely, while `DateMetadata` retains its existing API by delegating footer output.

**Tech Stack:** Ruby 3.2+, Jekyll 4.3–4.4, Minitest, RuboCop

---

### Task 1: Lock the expanded output contract

**Files:**
- Modify: `test/jekyll/agent_markdown_test.rb`
- Modify: `test/jekyll/date_metadata_test.rb`
- Modify: `test/jekyll/load_order_test.rb`
- Modify: `test/package_test.rb`

- [x] **Step 1: Update default and empty article expectations**

Expect exported metadata to end in `Published at: 2026-01-01 | Author: Example Author`, including empty-post output without a leading separator.

- [x] **Step 2: Cover independent configuration toggles**

Assert that `include_dates: false` produces an author-only footer, `include_author: false` produces a date-only footer, and disabling both produces the unchanged raw body.

- [x] **Step 3: Cover shared author normalization and missing values**

Extend mapping-form and missing-author tests to assert the per-article output as well as `llms.txt`.

- [x] **Step 4: Lock helper packaging and version 0.3.1**

Add the new helper files to direct-require and package assertions, and change the release-version expectation to `0.3.1`.

- [x] **Step 5: Verify RED**

Run `bundle exec rake test` and confirm failures show missing article author metadata, missing helpers, and version 0.3.0.

### Task 2: Share author and footer formatting

**Files:**
- Create: `lib/jekyll/agent_markdown/author_metadata.rb`
- Create: `lib/jekyll/agent_markdown/metadata_footer.rb`
- Modify: `lib/jekyll/agent_markdown/date_metadata.rb`
- Modify: `lib/jekyll/agent_markdown/llms_headings.rb`
- Modify: `lib/jekyll/agent_markdown/generator.rb`

- [x] **Step 1: Implement `AuthorMetadata`**

Resolve a scalar site `author` or mapping `author.name`, collapse whitespace, and return either `Author: <name>` or an empty string.

- [x] **Step 2: Implement `MetadataFooter`**

Reject empty entries, join the remainder with ` | `, preserve the existing body separator, and avoid a leading `---` for empty content.

- [x] **Step 3: Reuse the helpers**

Delegate `DateMetadata#append_to` to `MetadataFooter`, replace author parsing in `LlmsHeadings`, and build article footer entries from enabled date and author metadata in `Generator#post_content`.

- [x] **Step 4: Verify GREEN**

Run the focused test command and confirm all targeted tests pass.

### Task 3: Release and document version 0.3.1

**Files:**
- Modify: `lib/jekyll/agent_markdown/version.rb`
- Modify: `Gemfile.lock`
- Modify: `CHANGELOG.md`
- Modify: `README.md`

- [x] **Step 1: Bump release metadata**

Set the version constant and both lockfile references to `0.3.1`, and add a dated 0.3.1 changelog section for article author footers.

- [x] **Step 2: Document article author output**

Add author metadata to the article footer example and explain that `include_author` and `include_dates` independently control the shared footer.

- [x] **Step 3: Run full verification**

Run `bundle exec rake`; expect all Minitest tests and RuboCop to pass without errors.
