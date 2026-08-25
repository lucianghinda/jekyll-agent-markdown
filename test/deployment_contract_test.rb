# frozen_string_literal: true

require "test_helper"

module DeploymentContract
  ROOT = File.expand_path("..", __dir__)
  GUIDE = "docs/deployment.md"
  IMPLEMENTATIONS = %w[
    examples/cloudflare/src/worker.js
    examples/netlify/netlify/edge-functions/markdown-negotiation.ts
    examples/nginx/negotiation.js
  ].freeze
  ARTIFACTS = [
    GUIDE,
    "examples/cloudflare/wrangler.toml",
    IMPLEMENTATIONS[0],
    "examples/netlify/netlify.toml",
    IMPLEMENTATIONS[1],
    "examples/nginx/nginx.conf",
    IMPLEMENTATIONS[2]
  ].freeze
  PRIMARY_REFERENCES = %w[
    https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.1
    https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.5
    https://www.rfc-editor.org/rfc/rfc8288.html
    https://developers.cloudflare.com/workers/static-assets/binding/
    https://docs.netlify.com/build/edge-functions/api/
    https://docs.netlify.com/build/edge-functions/declarations/
    https://nginx.org/en/docs/http/ngx_http_js_module.html
    https://nginx.org/en/docs/njs/reference.html
  ].freeze

  private

  def artifact(path)
    File.binread(File.join(ROOT, path))
  end
end

class DeploymentGuideContractTest < Minitest::Test
  include DeploymentContract

  def test_guide_defines_default_precedence_and_tie_breaking
    guide = artifact(GUIDE)

    assert_includes guide, "Missing `Accept` or wildcard-only"
    assert_includes guide, "specificity"
    assert_includes guide, "explicit `q` values"
    assert_includes guide, "equal quality"
    assert_includes guide, "explicitly names `text/markdown`"
  end

  def test_guide_defines_exclusions_and_not_acceptable
    guide = artifact(GUIDE)

    assert_includes guide, "`q=0`"
    assert_includes guide, 'Accept: text/markdown;q="1"'
    assert_includes guide, "406 Not Acceptable"
  end

  def test_guide_requires_variant_response_headers
    guide = artifact(GUIDE)

    assert_includes guide, "Vary: Accept"
    assert_includes guide, 'rel="alternate"; type="text/markdown"'
    assert_includes guide, 'rel="alternate"; type="text/html"'
    assert_includes guide, "text/markdown; charset=utf-8"
    assert_includes guide, "text/html; charset=utf-8"
  end

  def test_guide_has_curl_and_public_scanner_release_checks
    guide = artifact(GUIDE)

    assert_includes guide, "curl"
    assert_includes guide, %(curl -sS -D - -o /dev/null -H 'Accept:' "$origin$article")
    assert_includes guide, "https://acceptmarkdown.com/public"
    assert_includes guide, "pre-release"
  end

  def test_guide_defines_representation_availability_and_fallback
    guide = artifact(GUIDE)

    assert_includes guide, "### Representation availability"
    assert_includes guide, "A negotiated Markdown variant that does not exist"
    assert_includes guide, "retries the HTML variant"
    assert_includes guide, "an explicit `.md` URL"
  end

  def test_guide_limits_negotiation_to_safe_request_methods
    guide = artifact(GUIDE)

    assert_includes guide, "### Request methods"
    assert_includes guide, "`GET` and `HEAD`"
    assert_includes guide, "405 Method Not Allowed"
  end

  def test_guide_treats_content_signal_as_owner_controlled_policy
    guide = artifact(GUIDE)

    assert_includes guide, "Content-Signal"
    assert_includes guide, "evolving"
    assert_includes guide, "site owner"
    assert_includes guide, "do not copy a generated crawler policy"
  end

  def test_guide_links_to_primary_protocol_and_platform_documentation
    guide = artifact(GUIDE)
    missing = PRIMARY_REFERENCES.reject { guide.include?(_1) }

    assert_empty missing
  end
end

class DeploymentHostContractTest < Minitest::Test
  include DeploymentContract

  def test_packages_every_deployment_artifact
    specification = Gem::Specification.load(File.join(ROOT, "jekyll-agent-markdown.gemspec"))

    assert_empty ARTIFACTS - specification.files
  end

  def test_every_implementation_encodes_precedence_and_tie_breaking
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_includes implementation, "specificity", path
      assert_includes implementation, "quality", path
      assert_includes implementation, "explicitMarkdown", path
    end
  end

  def test_every_implementation_honors_exclusions_and_not_acceptable
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_match(/quality\s*[!=<>]+\s*0/, implementation, path)
      assert_match(/separator < 1.*?sourceParameter\.trim\(\)\.toLowerCase\(\) === "q".*?quality = 0/m,
                   implementation, path)
      assert_includes implementation, "range.quality = parseQuality(rawValue.toLowerCase())", path
      assert_includes implementation, "406", path
    end
  end

  def test_every_implementation_merges_alternate_links_idempotently
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_includes implementation, "current.includes(alternate)", path
    end
  end

  def test_every_implementation_sets_variant_headers
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_includes implementation, "Vary", path
      assert_includes implementation, "Accept", path
      assert_includes implementation, "Link", path
      assert_includes implementation, "text/html; charset=utf-8", path
      assert_includes implementation, "text/markdown; charset=utf-8", path
    end
  end

  def test_explicit_markdown_paths_bypass_accept_negotiation
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_match(/explicitMarkdown.*\.endsWith\(["']\.md["']\)/, implementation, path)
      assert_match(/explicitMarkdown\s*\?\s*\{\s*selected:\s*["']markdown["']/m, implementation, path)
    end
  end

  def test_every_implementation_falls_back_to_html_when_markdown_is_absent
    IMPLEMENTATIONS.each do |path|
      implementation = artifact(path)

      assert_includes implementation, "htmlAcceptable", path
      assert_includes implementation, "fetchVariant", path
      assert_match(/status\s*[!=]==\s*404/, implementation, path)
    end
  end

  def test_nginx_rejects_methods_its_subrequest_cannot_represent
    implementation = artifact("examples/nginx/negotiation.js")

    assert_includes implementation, "SAFE_METHODS"
    assert_includes implementation, "r.headersOut.Allow"
    assert_includes implementation, "405"
  end

  def test_nginx_config_declares_asset_media_types
    config = artifact("examples/nginx/nginx.conf")

    assert_includes config, "include mime.types;"
    assert_includes config, "default_type"
  end

  def test_cloudflare_config_runs_the_worker_before_static_assets
    config = artifact("examples/cloudflare/wrangler.toml")

    assert_includes config, 'binding = "ASSETS"'
    assert_includes config, "run_worker_first = true"
  end

  def test_netlify_config_declares_the_edge_function
    config = artifact("examples/netlify/netlify.toml")

    assert_includes config, "[[edge_functions]]"
    assert_includes config, 'function = "markdown-negotiation"'
    assert_includes config, 'path = "/*"'
  end

  def test_nginx_config_uses_njs_and_an_internal_static_location
    config = artifact("examples/nginx/nginx.conf")

    assert_includes config, "js_import"
    assert_includes config, "js_content"
    assert_includes config, "internal;"
  end

  def test_nginx_preserves_end_to_end_asset_response_headers
    implementation = artifact("examples/nginx/negotiation.js")

    assert_includes implementation, "for (const name in reply.headersOut)"
    assert_includes implementation, "HOP_BY_HOP"
    assert_includes implementation, "connectionOptions(reply.headersOut)"
    assert_includes implementation, 'name.toLowerCase() !== "connection"'
    assert_includes implementation, 'excluded["content-length"] = true'
  end
end
