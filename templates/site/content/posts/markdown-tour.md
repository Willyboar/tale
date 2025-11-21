---
title = "Markdown Syntax Tour"
description = "A mega-post demonstrating Markdown and GFM output"
date = "2025-11-21"
tags = ["docs", "markdown", "syntax"]
---

# Markdown syntax tour

This document mirrors the Markdown reference at <https://www.markdownguide.org> so we can see how
common constructs are rendered inside the theme.

## Inline formatting

*Italic*, **strong**, ***strong italic***, `inline code`, ~~strikethrough~~, and
<ins>inserted text</ins> using raw HTML. Escape sequence: `\*` literally shows
an asterisk.

## Links & images

Link styles: [inline link](https://commonmark.org) or reference-style [docs][docs].

![Markdown logo](https://commonmark.org/help/images/favicon.png)

[docs]: https://commonmark.org/help/

## Lists

- Bullet one
- Bullet two
  - Nested bullet
    1. Ordered inside
    2. Still works
- [ ] Task unchecked
- [x] Task checked

1. Ordered list entry
2. Another entry
3. And a third

## Blockquotes

> Block quotes can contain paragraphs, **inline styles**, and nested lists.
>
> > A nested quote feels nice too.

## Footnotes

Markdown handles footnotes[^note] inline, great for references.[^ref]

[^note]: Rendered at the bottom with backlinks.
[^ref]: This one proves multiple notes work.

## Code blocks

```gleam
pub fn main() {
  io.println("Hello from Markdown fenced code!")
}
```

Indented code works too:

    touch src/app.gleam
    gleam test

## Tables

| Feature      | Status | Notes                        |
|--------------|--------|------------------------------|
| Inline code  | ✅     | Backticks everywhere.        |
| Task lists   | ✅     | Syntax uses `[ ]` and `[x]`.  |
| Footnotes    | ✅     | Great for citations.         |

## Thematic breaks

---

## Final paragraph

If something renders oddly, tweak the theme knowing every major Markdown feature is
represented here.
