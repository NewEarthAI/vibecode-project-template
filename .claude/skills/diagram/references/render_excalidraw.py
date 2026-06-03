#!/usr/bin/env python3
"""
Excalidraw Diagram Renderer — Playwright-based PNG generator.

Renders .excalidraw JSON to PNG for visual validation.
Uses headless Chromium + Excalidraw exportToSvg() via esm.sh CDN.

Usage:
    uv run python render_excalidraw.py <file.excalidraw> [-o path.png] [-s 2] [-w 1920]

Setup (first time):
    cd .claude/skills/diagram/references
    uv sync && uv run playwright install chromium

Adapted from coleam00/excalidraw-diagram-skill.
"""

import argparse
import json
import sys
from pathlib import Path

RENDER_TEMPLATE = Path(__file__).parent / "render_template.html"


def validate_excalidraw(data):
    errors = []
    if data.get("type") != "excalidraw":
        errors.append(f"Expected type 'excalidraw', got '{data.get('type')}'")
    if "elements" not in data:
        errors.append("Missing 'elements' array")
    elif not isinstance(data["elements"], list):
        errors.append("'elements' must be an array")
    if "appState" not in data:
        errors.append("Missing 'appState' object")
    for i, elem in enumerate(data.get("elements", [])):
        if "id" not in elem:
            errors.append(f"Element {i}: missing 'id'")
        if "type" not in elem:
            errors.append(f"Element {i}: missing 'type'")
    return errors


def compute_bounding_box(elements):
    if not elements:
        return (0, 0, 800, 600)

    min_x, min_y = float("inf"), float("inf")
    max_x, max_y = float("-inf"), float("-inf")

    for elem in elements:
        if elem.get("isDeleted"):
            continue
        x = elem.get("x", 0)
        y = elem.get("y", 0)
        w = elem.get("width", 0)
        h = elem.get("height", 0)

        if elem.get("type") in ("arrow", "line") and "points" in elem:
            for px, py in elem["points"]:
                min_x = min(min_x, x + px)
                min_y = min(min_y, y + py)
                max_x = max(max_x, x + px)
                max_y = max(max_y, y + py)
        else:
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x + abs(w))
            max_y = max(max_y, y + abs(h))

    padding = 80
    return (min_x - padding, min_y - padding, max_x + padding, max_y + padding)


def render(input_path, output_path=None, scale=2, max_width=1920):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        print("Error: playwright not installed.")
        print("Run: uv sync && uv run playwright install chromium")
        sys.exit(1)

    input_file = Path(input_path)
    if not input_file.exists():
        print(f"Error: File not found: {input_path}")
        sys.exit(1)

    try:
        with open(input_file) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}")
        sys.exit(1)

    errors = validate_excalidraw(data)
    if errors:
        print("Validation errors:")
        for err in errors:
            print(f"  - {err}")
        sys.exit(1)

    elements = [e for e in data.get("elements", []) if not e.get("isDeleted")]
    if not elements:
        print("Warning: No visible elements")

    min_x, min_y, max_x, max_y = compute_bounding_box(elements)
    dw = max_x - min_x
    dh = max_y - min_y
    vw = min(max_width, max(int(dw) + 100, 800))
    vh = max(int(dh) + 100, 600)

    if output_path is None:
        output_path = str(input_file.with_suffix(".png"))

    if not RENDER_TEMPLATE.exists():
        print(f"Error: Template not found: {RENDER_TEMPLATE}")
        sys.exit(1)

    print(f"Rendering: {input_path}")
    print(f"  Elements: {len(elements)}, Size: {int(dw)}x{int(dh)}")
    print(f"  Viewport: {vw}x{vh} @ {scale}x")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(
            viewport={"width": vw, "height": vh},
            device_scale_factor=scale,
        )
        page = ctx.new_page()
        page.goto(f"file://{RENDER_TEMPLATE.resolve()}")

        print("  Loading Excalidraw library...")
        page.wait_for_function("window.__moduleReady === true", timeout=120000)

        json_str = json.dumps(data)
        result = page.evaluate(f"window.renderDiagram({json_str})")

        if not result or not result.get("success"):
            msg = result.get("error", "Unknown") if result else "No result"
            print(f"Error: Render failed: {msg}")
            browser.close()
            sys.exit(1)

        page.wait_for_function("window.__renderComplete === true", timeout=15000)

        svg_el = page.query_selector("#svg-container svg")
        if svg_el:
            svg_el.screenshot(path=output_path)
        else:
            page.screenshot(path=output_path, full_page=True)

        browser.close()

    print(f"  Output: {output_path}")
    print("Done!")
    return output_path


def main():
    ap = argparse.ArgumentParser(description="Render Excalidraw JSON to PNG")
    ap.add_argument("input", help="Path to .excalidraw file")
    ap.add_argument("-o", "--output", help="Output PNG path")
    ap.add_argument("-s", "--scale", type=int, default=2, help="Scale (default: 2)")
    ap.add_argument("-w", "--width", type=int, default=1920, help="Max width (default: 1920)")
    args = ap.parse_args()
    render(args.input, args.output, args.scale, args.width)


if __name__ == "__main__":
    main()

