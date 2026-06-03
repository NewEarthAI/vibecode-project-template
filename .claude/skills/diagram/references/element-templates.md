# Excalidraw Element Templates — Copy-Paste Ready

All templates use placeholder colors. **Always replace with values from `color-palette.md`** based on semantic purpose.

Seeds must be unique per element. Use section namespacing: Section 1 = `100000-199999`, Section 2 = `200000-299999`, etc.

---

## Free-Floating Text (No Container)

Use for: labels, descriptions, annotations, section titles. This is the DEFAULT — use this instead of putting text in boxes.

```json
{
  "id": "section1_label_text",
  "type": "text",
  "x": 100,
  "y": 50,
  "width": 200,
  "height": 25,
  "angle": 0,
  "strokeColor": "#1e40af",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a0",
  "roundness": null,
  "seed": 100001,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false,
  "text": "Section Title",
  "originalText": "Section Title",
  "fontSize": 20,
  "fontFamily": 3,
  "textAlign": "left",
  "verticalAlign": "top",
  "containerId": null,
  "lineHeight": 1.25
}
```

**Font sizes by hierarchy:**
- Title: `28-32`
- Subtitle: `20-24`
- Body/detail: `14-16`
- Small annotation: `12`

---

## Line (Structural — NOT an Arrow)

Use for: timelines, tree structures, dividers, hierarchy connectors.

```json
{
  "id": "section1_timeline_line",
  "type": "line",
  "x": 100,
  "y": 100,
  "width": 0,
  "height": 400,
  "angle": 0,
  "strokeColor": "#64748b",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a1",
  "roundness": null,
  "seed": 100002,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false,
  "points": [[0, 0], [0, 400]],
  "lastCommittedPoint": null,
  "startBinding": null,
  "endBinding": null,
  "startArrowhead": null,
  "endArrowhead": null
}
```

**Variations:**
- Horizontal: `"points": [[0, 0], [400, 0]]`
- Diagonal: `"points": [[0, 0], [200, 150]]`
- Dashed: `"strokeStyle": "dashed"`

---

## Small Marker Dot

Use for: timeline points, bullet markers, step indicators.

```json
{
  "id": "section1_marker_dot",
  "type": "ellipse",
  "x": 94,
  "y": 94,
  "width": 12,
  "height": 12,
  "angle": 0,
  "strokeColor": "#1e3a5f",
  "backgroundColor": "#3b82f6",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a2",
  "roundness": null,
  "seed": 100003,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

---

## Rectangle — Hero Size (Visual Anchor)

Use for: most important concept, pipeline entry/exit points, central hubs.

```json
{
  "id": "section1_main_rect",
  "type": "rectangle",
  "x": 100,
  "y": 100,
  "width": 300,
  "height": 150,
  "angle": 0,
  "strokeColor": "#1e3a5f",
  "backgroundColor": "#3b82f6",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a3",
  "roundness": { "type": 3 },
  "seed": 100004,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": [
    { "id": "section1_main_text", "type": "text" },
    { "id": "section1_arrow_out", "type": "arrow" }
  ],
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

**Sizes:**
- Hero: `300 x 150`
- Primary: `180 x 90`
- Secondary: `120 x 60`
- Small: `60 x 40`

---

## Rectangle — Primary Size (Standard Element)

```json
{
  "id": "section1_step1_rect",
  "type": "rectangle",
  "x": 500,
  "y": 130,
  "width": 180,
  "height": 90,
  "angle": 0,
  "strokeColor": "#1e3a5f",
  "backgroundColor": "#60a5fa",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a4",
  "roundness": { "type": 3 },
  "seed": 100005,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": [
    { "id": "section1_step1_text", "type": "text" }
  ],
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

---

## Ellipse (Start/End Point)

```json
{
  "id": "section1_start_ellipse",
  "type": "ellipse",
  "x": 50,
  "y": 125,
  "width": 120,
  "height": 80,
  "angle": 0,
  "strokeColor": "#c2410c",
  "backgroundColor": "#fed7aa",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a5",
  "roundness": null,
  "seed": 100006,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": [
    { "id": "section1_start_text", "type": "text" }
  ],
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

---

## Diamond (Decision)

```json
{
  "id": "section1_decision_diamond",
  "type": "diamond",
  "x": 400,
  "y": 100,
  "width": 150,
  "height": 150,
  "angle": 0,
  "strokeColor": "#b45309",
  "backgroundColor": "#fef3c7",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a6",
  "roundness": null,
  "seed": 100007,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": [
    { "id": "section1_decision_text", "type": "text" },
    { "id": "section1_arrow_yes", "type": "arrow" },
    { "id": "section1_arrow_no", "type": "arrow" }
  ],
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

---

## Text Inside a Shape (Contained Text)

The `containerId` must match the parent shape's `id`. The parent shape must list this text in `boundElements`.

```json
{
  "id": "section1_main_text",
  "type": "text",
  "x": 150,
  "y": 160,
  "width": 200,
  "height": 25,
  "angle": 0,
  "strokeColor": "#ffffff",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a7",
  "roundness": null,
  "seed": 100008,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false,
  "text": "Fleet Router",
  "originalText": "Fleet Router",
  "fontSize": 16,
  "fontFamily": 3,
  "textAlign": "center",
  "verticalAlign": "middle",
  "containerId": "section1_main_rect",
  "lineHeight": 1.25
}
```

**Critical**: Text `x`, `y` should be approximately centered within the parent shape. For a 300x150 rect at (100, 100): text x ~ 150, y ~ 162.

---

## Arrow (With Bindings)

**Both the arrow AND connected shapes must reference each other.**

```json
{
  "id": "section1_arrow_out",
  "type": "arrow",
  "x": 400,
  "y": 175,
  "width": 100,
  "height": 0,
  "angle": 0,
  "strokeColor": "#64748b",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 2,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a8",
  "roundness": { "type": 2 },
  "seed": 100009,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false,
  "points": [[0, 0], [100, 0]],
  "lastCommittedPoint": null,
  "startBinding": {
    "elementId": "section1_main_rect",
    "focus": 0,
    "gap": 5
  },
  "endBinding": {
    "elementId": "section1_step1_rect",
    "focus": 0,
    "gap": 5
  },
  "startArrowhead": null,
  "endArrowhead": "arrow"
}
```

**Arrow variations:**
- Curved: Add mid-point: `"points": [[0, 0], [50, -40], [100, 0]]`
- Vertical: `"points": [[0, 0], [0, 100]]`
- Dashed: `"strokeStyle": "dashed"` (for optional paths)
- Bidirectional: `"startArrowhead": "arrow"` + `"endArrowhead": "arrow"`

---

## Evidence Artifact — Code Snippet

Dark background rectangle with light text for code/data evidence.

**Rectangle (container):**
```json
{
  "id": "evidence_code_rect",
  "type": "rectangle",
  "x": 100,
  "y": 400,
  "width": 280,
  "height": 80,
  "angle": 0,
  "strokeColor": "#475569",
  "backgroundColor": "#1e293b",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "a9",
  "roundness": { "type": 3 },
  "seed": 100010,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": [
    { "id": "evidence_code_text", "type": "text" }
  ],
  "updated": 1709337600000,
  "link": null,
  "locked": false
}
```

**Text (code content):**
```json
{
  "id": "evidence_code_text",
  "type": "text",
  "x": 110,
  "y": 425,
  "width": 260,
  "height": 30,
  "angle": 0,
  "strokeColor": "#22c55e",
  "backgroundColor": "transparent",
  "fillStyle": "solid",
  "strokeWidth": 1,
  "strokeStyle": "solid",
  "roughness": 0,
  "opacity": 100,
  "groupIds": [],
  "frameId": null,
  "index": "aA",
  "roundness": null,
  "seed": 100011,
  "version": 1,
  "versionNonce": 1,
  "isDeleted": false,
  "boundElements": null,
  "updated": 1709337600000,
  "link": null,
  "locked": false,
  "text": "save_record()",
  "originalText": "save_record()",
  "fontSize": 14,
  "fontFamily": 3,
  "textAlign": "left",
  "verticalAlign": "middle",
  "containerId": "evidence_code_rect",
  "lineHeight": 1.25
}
```

---

## Binding Checklist

When creating arrows between shapes:

1. Arrow has `startBinding.elementId` -> source shape ID
2. Arrow has `endBinding.elementId` -> target shape ID
3. Source shape has `boundElements: [{"id": "arrow_id", "type": "arrow"}]`
4. Target shape has `boundElements: [{"id": "arrow_id", "type": "arrow"}]`
5. Shape with contained text has `boundElements: [{"id": "text_id", "type": "text"}, ...]`
6. Text element has `containerId: "shape_id"`

**Missing any of these = broken diagram.** Always verify bidirectional bindings.

---

*Templates adapted from coleam00/excalidraw-diagram-skill. All colors are placeholders — use color-palette.md.*
