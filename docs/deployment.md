# Deploy HTML and Markdown variants

`jekyll-agent-markdown` writes files; the web host decides how those files are represented over HTTP. This guide defines one negotiation contract and provides dependency-free starting points for Cloudflare Workers, Netlify Edge Functions, and nginx with njs.

The packaged examples assume Jekyll's pretty permalinks: an HTML URL such as `/articles/example/` is backed by `_site/articles/example/index.html`, while this plugin writes `_site/articles/example.md`. They also map `/` to `/index.md`, remove `.html` or `.htm` before adding `.md`, and map an extensionless `/example` to `/example.md`. Adapt the path helpers if the site uses a different permalink scheme. Build the site first and point each example's `_site` setting at that output.

## Negotiation contract

Apply negotiation to page URLs, not to CSS, JavaScript, images, fonts, or other static assets.

| Request | Result |
| --- | --- |
| Missing `Accept` or wildcard-only `Accept: */*` | HTML |
| A more specific media range | Its `q` value overrides a less-specific wildcard for that representation |
| Different effective HTML and Markdown quality | The supported representation with the larger quality wins |
| At equal quality | Markdown wins only when the request explicitly names `text/markdown`; otherwise HTML wins |
| A representation with effective `q=0` | Excluded, even if a less-specific wildcard has a positive quality |
| Neither `text/html` nor `text/markdown` acceptable | `406 Not Acceptable` |
| A negotiated Markdown variant that does not exist | HTML when HTML is acceptable; otherwise the Markdown `404` |
| A URL ending in `.md` | Markdown regardless of `Accept`; this URL is not negotiated |
| A method other than `GET` or `HEAD` | Not negotiated |

The examples calculate an effective quality independently for `text/html` and `text/markdown`. Media-range specificity is applied before explicit `q` values are compared: an exact type is more specific than `text/*`, which is more specific than `*/*`. Supported representation parameters, currently `charset=utf-8`, add specificity. Invalid quality values make that range unacceptable instead of silently broadening access.

This follows HTTP's [`Accept` precedence and quality rules](https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.1). Returning 406 is an intentional server policy when none of the available representations is acceptable; HTTP also permits a server to disregard the preference, but these examples do not. See [406 Not Acceptable](https://www.rfc-editor.org/rfc/rfc9110.html#section-15.5.7).

### Representation availability

Negotiation selects among representations that actually exist. This plugin exports posts by default, so on a site that has not enabled `pages` or `collections` most page URLs have no `.md` sibling. A request preferring Markdown for such a URL must not become a 404 when the host could have served HTML.

Each example therefore fetches the selected variant and, when a negotiated Markdown variant returns 404 and HTML is acceptable, retries the HTML variant and labels the response as HTML. Two cases deliberately do not fall back: an explicit `.md` URL, because that URL names one representation rather than negotiating, and a request that excluded HTML with `q=0`, because no acceptable representation exists.

### Request methods

Negotiation applies to `GET` and `HEAD`. The nginx example rejects other methods with `405 Method Not Allowed` and an `Allow` header, because an njs subrequest is always a `GET` and would otherwise turn a `POST` into a static read of the page body. The Cloudflare and Netlify examples hand non-page and non-matching requests to the platform's own asset handler, which applies its method rules.

## Response contract

Every successful variant has an explicit UTF-8 content type:

```http
Content-Type: text/html; charset=utf-8
```

or:

```http
Content-Type: text/markdown; charset=utf-8
```

Every response selected from `Accept`, including a 406 response, carries:

```http
Vary: Accept
```

`Vary` prevents a shared cache from reusing an HTML response for a Markdown request or the reverse. Preserve existing `Vary` fields when adding `Accept`; see the HTTP [`Vary` definition](https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.5).

HTML and Markdown advertise each other with a [`Link` response header](https://www.rfc-editor.org/rfc/rfc8288.html). For example:

```http
Link: </articles/example.md>; rel="alternate"; type="text/markdown"
```

and the Markdown response advertises HTML:

```http
Link: </articles/example/>; rel="alternate"; type="text/html"
```

The explicit `.md` URL always returns `text/markdown; charset=utf-8`, even if a caller sends `Accept: text/html`. The `text/markdown` media type is registered by [RFC 7763](https://www.rfc-editor.org/rfc/rfc7763.html).

## Cloudflare Workers

Copy [`examples/cloudflare`](../examples/cloudflare) into the deployment project, or adapt its paths. `wrangler.toml` binds the Jekyll output as `ASSETS` and sets `run_worker_first = true`; without that setting, a matching static asset can bypass negotiation. The Worker passes non-page assets straight through and uses `env.ASSETS.fetch()` for selected variants.

The relevant primary documentation is Cloudflare's [static assets binding and `run_worker_first` reference](https://developers.cloudflare.com/workers/static-assets/binding/). Set `compatibility_date` to the deployment project's chosen current date and confirm the `_site` path before deploying.

## Netlify Edge Functions

Copy [`examples/netlify/netlify.toml`](../examples/netlify/netlify.toml) and [`markdown-negotiation.ts`](../examples/netlify/netlify/edge-functions/markdown-negotiation.ts) to the corresponding locations in the site repository. The catch-all declaration is minimal and easy to test; narrow the declared paths or add exclusions on a large site to avoid invoking the function for assets that it only passes through.

The Edge Function calls `context.next()` for the requested HTML or explicit Markdown asset. When a page URL negotiates Markdown, it fetches the `.md` sibling; that same-site request runs the Edge Function again but terminates on the explicit `.md` branch. Review Netlify's [Edge Functions API](https://docs.netlify.com/build/edge-functions/api/) and [declaration and request-chain rules](https://docs.netlify.com/build/edge-functions/declarations/) before combining this example with other rewrites or Edge Functions.

## nginx with njs

Install nginx's JavaScript module, place [`negotiation.js`](../examples/nginx/negotiation.js) at `/etc/nginx/njs/negotiation.js`, adapt the `_site` filesystem path in [`nginx.conf`](../examples/nginx/nginx.conf), then validate and reload nginx. Current njs recommends the QuickJS engine; the example selects it with `js_engine qjs`. The example also sets `include mime.types` and a binary `default_type`, without which its pass-through location would serve CSS, JavaScript, fonts, and images as `text/plain`.

The public location delegates page requests to `js_content`. The handler performs an internal subrequest to a private static location, sets the variant headers, and returns the buffer. `subrequest_output_buffer_size` must exceed the largest generated page, so change the example's `10m` ceiling to fit the site's real output and memory budget. Consult the official [`ngx_http_js_module` directives](https://nginx.org/en/docs/http/ngx_http_js_module.html) and [njs request/subrequest API](https://nginx.org/en/docs/njs/reference.html).

## Pre-release verification

Replace the sample origin and article paths, deploy to a staging hostname, and run this curl matrix. Use GET with discarded bodies so the check exercises the same response path as production clients.

```sh
origin=https://staging.example.com
article=/articles/example/
markdown=/articles/example.md
page=/about/

curl -sS -D - -o /dev/null -H 'Accept:' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: */*' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/markdown' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/html, text/markdown' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/*;q=0.8, text/html;q=0.4' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/markdown;q=0, */*;q=0.8' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: application/json' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/markdown;q="1"' "$origin$article"
curl -sS -D - -o /dev/null -H 'Accept: text/html' "$origin$markdown"
curl -sS -D - -o /dev/null -H 'Accept: text/markdown' "$origin$page"
curl -sS -D - -o /dev/null -H 'Accept: text/markdown, text/html;q=0' "$origin$page"
```

Expected results, in order:

| Case | Status | Content-Type |
| --- | --- | --- |
| Missing `Accept` | 200 | `text/html; charset=utf-8` |
| Wildcard-only | 200 | `text/html; charset=utf-8` |
| Explicit Markdown | 200 | `text/markdown; charset=utf-8` |
| Equal explicit HTML and Markdown | 200 | `text/markdown; charset=utf-8` |
| More-specific HTML is lower quality than `text/*` Markdown | 200 | `text/markdown; charset=utf-8` |
| Exact Markdown exclusion overrides wildcard | 200 | `text/html; charset=utf-8` |
| Neither supported | 406 | `text/plain; charset=utf-8` |
| Invalid quoted quality | 406 | `text/plain; charset=utf-8` |
| Explicit `.md` despite HTML preference | 200 | `text/markdown; charset=utf-8` |
| Page with no Markdown sibling | 200 | `text/html; charset=utf-8` |
| Same page with HTML excluded | 404 | the host's own error representation |

For every negotiated 200 response, also verify `Vary: Accept` and the appropriate alternate `Link`. Check the explicit Markdown URL's HTML `Link`. Finally, submit representative public staging URLs to the [acceptmarkdown.com public scanner](https://acceptmarkdown.com/public) and retain its results with the release evidence. The scanner is a useful external pre-release check, not a substitute for the matrix or host logs.

## Crawler policy is separate

`Content-Signal` is an evolving crawler-policy convention, not a transport requirement for HTML/Markdown negotiation. Whether a site permits search, AI input, or model training is a decision for the site owner, informed by the site's content rights and legal advice. The examples deliberately do not generate crawler permissions. Review the current [Content Signals project](https://contentsignals.org/) and the behavior of the crawlers that matter to the site, then write and audit an owner-approved policy; do not copy a generated crawler policy without that review.

## Runtime gaps to validate

These packaged examples statically lock the shared HTTP behavior, but they are not deployed by this gem. Before production, validate host-specific routing, redirects, custom error pages, caching, compression, conditional requests, range requests, base paths, non-pretty permalinks, large response bodies, and interaction with any existing middleware. Confirm that a missing Markdown sibling produces the site's intended error rather than mislabeled content, and monitor 406 rates after launch for clients with unexpected `Accept` headers.
