const HTML = {
  name: "html",
  contentType: "text/html; charset=utf-8",
  type: "text",
  subtype: "html",
  parameters: {charset: "utf-8"}
};
const MARKDOWN = {
  name: "markdown",
  contentType: "text/markdown; charset=utf-8",
  type: "text",
  subtype: "markdown",
  parameters: {charset: "utf-8"}
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const explicitMarkdown = url.pathname.endsWith(".md");

    if (!isPagePath(url.pathname)) return env.ASSETS.fetch(request);

    const preference = explicitMarkdown
      ? {selected: "markdown", htmlAcceptable: false}
      : negotiate(request.headers.get("Accept"));
    if (!preference.selected) return notAcceptable();

    const paths = variantPaths(url.pathname, explicitMarkdown);
    const {response, served} = await fetchVariant(request, env, url, paths, preference);

    return decorate(response, served, paths, !explicitMarkdown);
  }
};

// A negotiated Markdown variant is not guaranteed to exist: the plugin exports
// posts by default, so most page URLs have no .md sibling until the site opts
// pages or collections in. Fall back to HTML when the client accepts it rather
// than turning a page the host could serve into a 404.
async function fetchVariant(request, env, url, paths, preference) {
  const response = await fetchAsset(request, env, url, paths[preference.selected]);
  const missing = response.status === 404;
  if (preference.selected !== "markdown" || !missing || !preference.htmlAcceptable) {
    return {response, served: preference.selected};
  }

  const fallback = await fetchAsset(request, env, url, paths.html);
  if (fallback.status === 404) return {response, served: "markdown"};

  return {response: fallback, served: "html"};
}

function fetchAsset(request, env, url, pathname) {
  const assetUrl = new URL(url);
  assetUrl.pathname = pathname;
  return env.ASSETS.fetch(new Request(assetUrl, request));
}

function negotiate(accept) {
  if (!accept || !accept.trim()) return {selected: "html", htmlAcceptable: true};

  const ranges = parseAccept(accept);
  const html = qualityFor(HTML, ranges);
  const markdown = qualityFor(MARKDOWN, ranges);
  const htmlAcceptable = html.quality > 0;

  if (html.quality <= 0 && markdown.quality <= 0) return {selected: null, htmlAcceptable};
  if (markdown.quality > html.quality) return {selected: "markdown", htmlAcceptable};
  if (html.quality > markdown.quality) return {selected: "html", htmlAcceptable};

  const explicitMarkdown = ranges.some((range) =>
    range.type === "text" &&
      range.subtype === "markdown" &&
      range.quality > 0 &&
      specificity(range, MARKDOWN) !== null
  );
  return {selected: explicitMarkdown ? "markdown" : "html", htmlAcceptable};
}

function qualityFor(representation, ranges) {
  let bestSpecificity = -1;
  let quality = 0;

  for (const range of ranges) {
    const rangeSpecificity = specificity(range, representation);
    if (rangeSpecificity === null || rangeSpecificity < bestSpecificity) continue;

    if (rangeSpecificity > bestSpecificity) {
      bestSpecificity = rangeSpecificity;
      quality = range.quality;
    } else {
      quality = Math.max(quality, range.quality);
    }
  }

  return {quality, specificity: bestSpecificity};
}

function specificity(range, representation) {
  if (range.type === "*" && range.subtype !== "*") return null;
  if (range.type !== "*" && range.type !== representation.type) return null;
  if (range.subtype !== "*" && range.subtype !== representation.subtype) return null;

  for (const [name, value] of Object.entries(range.parameters)) {
    if (representation.parameters[name] !== value) return null;
  }

  const mediaSpecificity = range.type === "*" ? 0 : range.subtype === "*" ? 1 : 2;
  return (mediaSpecificity * 100) + Object.keys(range.parameters).length;
}

function parseAccept(accept) {
  return splitQuoted(accept, ",").map(parseRange).filter(Boolean);
}

function parseRange(source) {
  const parts = splitQuoted(source, ";");
  const media = parts.shift().trim().toLowerCase();
  const match = media.match(/^([^/\s]+)\/([^/\s]+)$/);
  if (!match) return null;

  const range = {type: match[1], subtype: match[2], quality: 1, parameters: {}};
  for (const sourceParameter of parts) {
    const separator = sourceParameter.indexOf("=");
    if (separator < 1) {
      if (sourceParameter.trim().toLowerCase() === "q") range.quality = 0;
      continue;
    }

    const name = sourceParameter.slice(0, separator).trim().toLowerCase();
    const rawValue = sourceParameter.slice(separator + 1).trim();
    if (name === "q") {
      range.quality = parseQuality(rawValue.toLowerCase());
    } else {
      range.parameters[name] = unquote(rawValue).toLowerCase();
    }
  }

  return range;
}

function parseQuality(value) {
  return /^(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/.test(value) ? Number(value) : 0;
}

function splitQuoted(source, separator) {
  const parts = [];
  let current = "";
  let quoted = false;
  let escaped = false;

  for (const character of source) {
    if (escaped) {
      current += character;
      escaped = false;
    } else if (character === "\\" && quoted) {
      current += character;
      escaped = true;
    } else if (character === '"') {
      current += character;
      quoted = !quoted;
    } else if (character === separator && !quoted) {
      parts.push(current);
      current = "";
    } else {
      current += character;
    }
  }

  parts.push(current);
  return parts;
}

function unquote(value) {
  if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
    return value.slice(1, -1).replace(/\\(.)/g, "$1");
  }
  return value;
}

function isPagePath(pathname) {
  const finalSegment = pathname.split("/").pop();
  return pathname.endsWith("/") || /\.html?$/.test(pathname) || !finalSegment.includes(".") || pathname.endsWith(".md");
}

function variantPaths(pathname, explicitMarkdown) {
  if (explicitMarkdown) return {html: htmlPathFor(pathname), markdown: pathname};
  return {html: pathname, markdown: markdownPathFor(pathname)};
}

function markdownPathFor(pathname) {
  if (pathname === "/") return "/index.md";
  if (pathname.endsWith("/")) return `${pathname.slice(0, -1)}.md`;
  if (/\.html?$/.test(pathname)) return pathname.replace(/\.html?$/, ".md");
  return `${pathname}.md`;
}

function htmlPathFor(pathname) {
  if (pathname === "/index.md") return "/";
  return `${pathname.slice(0, -3)}/`;
}

function decorate(response, selected, paths, negotiated) {
  const headers = new Headers(response.headers);
  if (negotiated) mergeVary(headers, "Accept");

  if (response.status < 200 || response.status >= 300) {
    return new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers
    });
  }

  const representation = selected === "markdown" ? MARKDOWN : HTML;
  headers.set("Content-Type", representation.contentType);
  appendLink(headers, alternateLink(selected, paths));

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers
  });
}

function alternateLink(selected, paths) {
  const alternate = selected === "markdown" ? "html" : "markdown";
  return `<${paths[alternate]}>; rel="alternate"; type="text/${alternate}"`;
}

function appendLink(headers, alternate) {
  const current = headers.get("Link");
  headers.set("Link", mergeLink(current, alternate));
}

function mergeLink(current, alternate) {
  if (!current || current.includes(alternate)) return current || alternate;
  return `${current}, ${alternate}`;
}

function mergeVary(headers, field) {
  const fields = (headers.get("Vary") || "").split(",").map((value) => value.trim()).filter(Boolean);
  if (!fields.some((value) => value.toLowerCase() === field.toLowerCase())) fields.push(field);
  headers.set("Vary", fields.join(", "));
}

function notAcceptable() {
  return new Response("Not Acceptable\n", {
    status: 406,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      Vary: "Accept"
    }
  });
}
