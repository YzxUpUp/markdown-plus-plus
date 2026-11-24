"use strict";

const parser = window.markdownit({ html: false });
const preview = document.getElementById("preview");

// The editor writes standard HTML spans for font size. Only this pattern is
// rendered as markup, and the enclosed Markdown goes through the same parser.
parser.inline.ruler.before("html_inline", "markdown_font_size", (state, silent) => {
    if (state.src.charCodeAt(state.pos) !== 60) return false;
    const match = /^<span style="font-size: (12|14|16|18|20|24|28|32)px">([^<\r\n]*)<\/span>/.exec(
        state.src.slice(state.pos, state.posMax)
    );
    if (!match) return false;
    if (!silent) {
        const opening = state.push("span_open", "span", 1);
        opening.attrSet("class", "size-" + match[1]);
        const inner = [];
        parser.inline.parse(match[2], parser, state.env, inner);
        state.tokens.push(...inner);
        state.push("span_close", "span", -1);
    }
    state.pos += match[0].length;
    return true;
});

const originalImageRenderer = parser.renderer.rules.image;
parser.renderer.rules.image = (tokens, index, options, environment, renderer) => {
    const token = tokens[index];
    const source = token.attrGet("src");
    if (source?.startsWith("//")) {
        token.attrSet("src", "https:" + source);
    } else if (source && !/^(https?:|data:)/i.test(source)) {
        token.attrSet("src", "markdown-image://asset/image?source=" + encodeURIComponent(source)
                            + "&revision=" + environment.revision);
    }
    return originalImageRenderer(tokens, index, options, environment, renderer);
};

window.renderMarkdown = (source, revision) => {
    preview.innerHTML = parser.render(source, { revision });
    const used = new Set();
    for (const heading of preview.querySelectorAll("h1,h2,h3,h4,h5,h6")) {
        const base = heading.textContent.trim().toLowerCase()
            .replace(/[^\p{L}\p{N}\s_-]/gu, "").replace(/\s+/g, "-");
        let id = base;
        let suffix = 1;
        while (used.has(id)) id = base + "-" + suffix++;
        if (id) {
            used.add(id);
            heading.id = id;
        }
    }
};

preview.addEventListener("click", event => {
    const link = event.target.closest("a[href]");
    if (!link) return;
    event.preventDefault();
    const target = link.getAttribute("href");
    if (target.startsWith("#")) {
        try {
            document.getElementById(decodeURIComponent(target.slice(1)))?.scrollIntoView();
        } catch {
            // Ignore malformed fragments.
        }
    } else {
        window.webkit.messageHandlers.openMarkdownLink.postMessage(target);
    }
});
