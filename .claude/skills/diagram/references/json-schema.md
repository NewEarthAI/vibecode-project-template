# Excalidraw JSON Format Reference

## Root Structure

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "https://excalidraw.com",
  "elements": [],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": 20 },
  "files": {}
}
```

## Base Element Properties

| Property | Type | Notes |
|----------|------|-------|
| `id` | string | Unique descriptive: `batch_control_rect` |
| `type` | string | `rectangle`, `ellipse`, `diamond`, `arrow`, `line`, `text`, `frame` |
| `x`, `y` | number | Top-left canvas position |
| `width`, `height` | number | Bounding box pixels |
| `fillStyle` | string | `"solid"`, `"hachure"`, `"cross-hatch"` |
| `strokeStyle` | string | `"solid"`, `"dashed"`, `"dotted"` |
| `roughness` | number | **Always 0** |
| `opacity` | number | **Always 100** |
| `roundness` | object/null | `{"type": 3}` = rounded, `null` = sharp |
| `seed` | number | Unique per element, namespace by section |
| `boundElements` | array/null | `[{"id":"arrow1","type":"arrow"}]` |
| `groupIds` | array | Group membership |
| `angle` | number | Radians, usually `0` |
| `index` | string | Order: `"a0"`, `"a1"` |
| `version` | number | `1` |
| `versionNonce` | number | `1` |
| `isDeleted` | boolean | `false` |
| `frameId` | null | Parent frame |
| `updated` | number | Timestamp ms |
| `link` | null | Hyperlink |
| `locked` | boolean | `false` |

## Text Properties

| Property | Values | Notes |
|----------|--------|-------|
| `text` | string | **Readable words only** |
| `originalText` | string | Same as `text` |
| `fontSize` | number | Title: 28-32, Subtitle: 20-24, Body: 14-16, Small: 12 |
| `fontFamily` | number | **Always 3** (Cascadia monospace) |
| `textAlign` | string | `"left"`, `"center"`, `"right"` |
| `verticalAlign` | string | `"top"`, `"middle"`, `"bottom"` |
| `containerId` | string/null | Parent shape ID if inside container |
| `lineHeight` | number | `1.25` |

## Arrow Properties

| Property | Notes |
|----------|-------|
| `points` | **First point MUST be `[0, 0]`**, rest are relative offsets |
| `lastCommittedPoint` | `null` |
| `startBinding` | `{"elementId":"id", "focus":0, "gap":5}` or `null` |
| `endBinding` | `{"elementId":"id", "focus":0, "gap":5}` or `null` |
| `startArrowhead` | `null`, `"arrow"`, `"dot"`, `"bar"`, `"triangle"` |
| `endArrowhead` | Usually `"arrow"` |

## Line Properties

Same as arrow but: `startBinding: null`, `endBinding: null`, no arrowheads.

## AppState (Minimal)

```json
{
  "viewBackgroundColor": "#ffffff",
  "gridSize": 20,
  "gridModeEnabled": false,
  "theme": "light",
  "viewModeEnabled": false
}
```

## Validation Checklist

- [ ] Top-level: `type`, `version`, `source`, `elements`, `appState`, `files`
- [ ] `type` = `"excalidraw"`, `version` = `2`
- [ ] Each element: unique `id` + unique `seed`
- [ ] Arrows: `points` starts `[0, 0]`
- [ ] Bindings **bidirectional**: arrow refs shape AND shape refs arrow
- [ ] Contained text: `containerId` set, parent lists text in `boundElements`
- [ ] Colors from `color-palette.md` only
- [ ] `roughness: 0`, `opacity: 100`, `fontFamily: 3`

*Ref: https://docs.excalidraw.com/docs/codebase/json-schema*
