# Extracting specs from Figma (MCP)

When the design source is Figma accessed through the Figma MCP server, these tools each
return a different slice. Use them in this order — going straight to a screenshot loses
the exact values and the layout tree.

You need a **node id** and a **file key**. From a URL like
`https://figma.com/design/<fileKey>/<name>?node-id=1-2`, the node id is `1:2` (or `1-2`)
and the file key is `<fileKey>`. If the URL has no `node-id`, ask for a node-specific URL
rather than guessing.

## Tool order

1. **`get_metadata`** — the node tree (ids, names, sizes, positions). Use it to orient and
   to find the *right* sub-node. A top-level node is often a documentation/spec page; the
   thing you want to copy is usually a specific assembled instance inside it. Pick the node
   whose name and size match the real component, not an annotation frame.

2. **`get_design_context`** — the generated code + screenshot for the target node. This is
   the authoritative source for:
   - exact px: sizes, padding, gaps, radius
   - typography: font, weight, size, line-height, letter-spacing
   - **layout tree**: how children are grouped, which element is `flex:1 / flex-[1_0_0]`,
     which is `shrink-0`, what's right-aligned, which element owns the ellipsis. This is
     how you catch *structural* differences a screenshot can't show.
   It also lists the design tokens present in the node (e.g. `fill_primary: #141414`).

3. **`get_variable_defs`** — the named variable/token values bound on the node, e.g.
   `{"semantic/bg_disable":"#CCCCCC","color/icon/primary":"#141414"}`. Use this to resolve
   a color to its *semantic token name*, then map that to the project's matching token.

4. **`get_screenshot`** (high `maxDimension`) — render a specific node/state to confirm
   things the code dump can't tell you: the actual color of a disabled vs. active state,
   an icon's fill vs. stroke, where a glyph sits inside a shape. Capture each state
   separately (e.g. the incomplete row and the complete row) and inspect them directly.

## Gotchas

- **Annotation vs. real component.** Spec pages contain rows like "title + count" as
  *labels*, and separate fully-assembled instances. Copy values from the assembled
  instance (it has the real spacing/connectors/reward areas), not the label frame.
- **A top-level node may render empty.** If a screenshot of the node id you were given
  shows only a skeleton, drill into its children/instances via `get_metadata` and capture
  those instead.
- **The generated code is Tailwind/React regardless of your stack.** Don't copy it
  verbatim. Read it for the *values and structure*, then translate into the project's
  styling system and tokens.
- **Icons are often composite.** A "circle-check" may be one filled icon in the design but
  is fine to implement as a colored circle + a checkmark glyph in code — match the
  resulting size/colors, not the asset packaging. Note which part changes per state (often
  only the container color changes while the glyph stays white).
- **Treat asset URLs as short-lived secrets.** Screenshot/asset URLs from the MCP expire;
  download what you need promptly and don't paste them around.
