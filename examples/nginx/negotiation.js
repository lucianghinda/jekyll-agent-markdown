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
const HOP_BY_HOP = {
    connection: true,
    "keep-alive": true,
    "proxy-authenticate": true,
    "proxy-authorization": true,
    "proxy-connection": true,
    te: true,
    trailer: true,
    "transfer-encoding": true,
    upgrade: true
};
const SAFE_METHODS = {GET: true, HEAD: true};

async function serve(r) {
    // njs subrequests are always GET, so a POST or DELETE reaching this handler
    // would be silently downgraded into a static read of the page body.
    if (!SAFE_METHODS[r.method]) {
        r.headersOut.Allow = "GET, HEAD";
        r.headersOut["Content-Type"] = "text/plain; charset=utf-8";
        r.return(405, "Method Not Allowed\n");
        return;
    }

    const explicitMarkdown = r.uri.endsWith(".md");
    const preference = explicitMarkdown
        ? {selected: "markdown", htmlAcceptable: false}
        : negotiate(r.headersIn.Accept);

    if (!preference.selected) {
        r.headersOut["Content-Type"] = "text/plain; charset=utf-8";
        r.headersOut.Vary = mergeVary(r.headersOut.Vary, "Accept");
        r.return(406, "Not Acceptable\n");
        return;
    }

    const paths = variantPaths(r.uri, explicitMarkdown);
    const variant = await fetchVariant(r, paths, preference, explicitMarkdown);
    const reply = variant.reply;

    copyResponseHeaders(r, reply);
    if (!explicitMarkdown) r.headersOut.Vary = mergeVary(reply.headersOut.Vary, "Accept");

    if (reply.status < 200 || reply.status >= 300) {
        r.return(reply.status, reply.responseBuffer);
        return;
    }

    const representation = variant.served === "markdown" ? MARKDOWN : HTML;
    r.headersOut["Content-Type"] = representation.contentType;
    r.headersOut.Link = mergeLink(reply.headersOut.Link, alternateLink(variant.served, paths));
    r.return(reply.status, reply.responseBuffer);
}

// A negotiated Markdown variant is not guaranteed to exist: the plugin exports
// posts by default, so most page URLs have no .md sibling until the site opts
// pages or collections in. Fall back to HTML when the client accepts it rather
// than turning a page the host could serve into a 404.
async function fetchVariant(r, paths, preference, explicitMarkdown) {
    const reply = await r.subrequest(`/_jekyll_asset${paths[preference.selected]}`);
    if (preference.selected !== "markdown" || explicitMarkdown) {
        return {reply, served: preference.selected};
    }
    if (reply.status !== 404 || !preference.htmlAcceptable) return {reply, served: "markdown"};

    const fallback = await r.subrequest(`/_jekyll_asset${paths.html}`);
    if (fallback.status === 404) return {reply, served: "markdown"};

    return {reply: fallback, served: "html"};
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

    for (const name in range.parameters) {
        if (representation.parameters[name] !== range.parameters[name]) return null;
    }

    const mediaSpecificity = range.type === "*" ? 0 : range.subtype === "*" ? 1 : 2;
    return (mediaSpecificity * 100) + Object.keys(range.parameters).length;
}

function parseAccept(accept) {
    return splitQuoted(accept, ",").map(parseRange).filter((range) => range !== null);
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

function alternateLink(selected, paths) {
    const alternate = selected === "markdown" ? "html" : "markdown";
    return `<${paths[alternate]}>; rel="alternate"; type="text/${alternate}"`;
}

function mergeVary(current, field) {
    const fields = (current || "").split(",").map((value) => value.trim()).filter(Boolean);
    if (!fields.some((value) => value.toLowerCase() === field.toLowerCase())) fields.push(field);
    return fields.join(", ");
}

function mergeLink(current, alternate) {
    if (!current || current.includes(alternate)) return current || alternate;
    return `${current}, ${alternate}`;
}

function copyResponseHeaders(r, reply) {
    const excluded = connectionOptions(reply.headersOut);
    for (const name in HOP_BY_HOP) excluded[name] = true;
    excluded["content-length"] = true;

    for (const name in reply.headersOut) {
        if (excluded[name.toLowerCase()]) continue;
        r.headersOut[name] = reply.headersOut[name];
    }
}

function connectionOptions(headers) {
    const options = {};
    for (const name in headers) {
        if (name.toLowerCase() !== "connection") continue;

        const values = Array.isArray(headers[name]) ? headers[name] : [headers[name]];
        for (const value of values) {
            for (const token of String(value).split(",")) {
                const option = token.trim().toLowerCase();
                if (option) options[option] = true;
            }
        }
    }
    return options;
}

export default {serve};
