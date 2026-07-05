#!/bin/bash
# Landing Page MVP — Quality Gate v2.3
# Run after: npm run build
# Exit 0 on pass, exit 1 on failure

PASS=0; WARN=0; FAIL=0

echo "━━━ LANDING PAGE MVP — QUALITY GATE v2.3 ━━━"
echo ""

# ── GATE 1: Dependency Verification ──────────────────────
echo "── Gate 1: Dependencies ──"
for dep in gsap @gsap/react lucide-react clsx; do
  if grep -q "\"$dep\"" package.json 2>/dev/null; then
    echo "  PASS: $dep present"
    ((PASS++))
  else
    echo "  FAIL: $dep MISSING from package.json"
    ((FAIL++))
  fi
done

# ── GATE 2: Build Verification ───────────────────────────
echo ""
echo "── Gate 2: Build ──"
BUILD_OUTPUT=$(npm run build 2>&1)
if echo "$BUILD_OUTPUT" | grep -q "built in"; then
  echo "  PASS: Vite build succeeded"
  ((PASS++))
else
  echo "  FAIL: Vite build FAILED"
  echo "$BUILD_OUTPUT" | tail -5
  ((FAIL++))
fi

# ── GATE 3: GSAP Safety (CRITICAL) ──────────────────────
echo ""
echo "── Gate 3: GSAP Safety ──"
UNSAFE=$(grep -rn 'useEffect.*gsap\|useEffect.*ScrollTrigger\|useEffect.*gsap\.to\|useEffect.*gsap\.from' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNSAFE" -eq 0 ]; then
  echo "  PASS: All animations use useGSAP() (no raw useEffect+GSAP)"
  ((PASS++))
else
  echo "  FAIL: $UNSAFE raw useEffect+GSAP instance(s) found — MUST use useGSAP()"
  grep -rn 'useEffect.*gsap\|useEffect.*ScrollTrigger' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | head -5
  ((FAIL++))
fi

# Check for force3D default
FORCE3D=$(grep -rn 'force3D' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$FORCE3D" -gt 0 ]; then
  echo "  PASS: force3D directive found"
  ((PASS++))
else
  echo "  WARN: No force3D directive — add gsap.defaults({ force3D: true })"
  ((WARN++))
fi

# Check for matchMedia (responsive cleanup)
MATCHMEDIA=$(grep -rn 'matchMedia' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$MATCHMEDIA" -gt 0 ]; then
  echo "  PASS: gsap.matchMedia() found for responsive cleanup"
  ((PASS++))
else
  echo "  WARN: No gsap.matchMedia() — desktop animations may persist on mobile"
  ((WARN++))
fi

# Check for prefers-reduced-motion guard (a11y mandate — GSAP Rule 6)
MOTION_PRESENT=$(grep -rn 'gsap\.\(to\|from\|fromTo\|timeline\)\|ScrollTrigger' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
REDUCED_MOTION=$(grep -rn 'prefers-reduced-motion\|reduce:' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "${MOTION_PRESENT:-0}" -eq 0 ] || [ "${REDUCED_MOTION:-0}" -gt 0 ]; then
  echo "  PASS: prefers-reduced-motion guard present (or no motion to guard)"
  ((PASS++))
else
  echo "  WARN: motion present but no prefers-reduced-motion branch (GSAP Rule 6 — a11y mandate)"
  ((WARN++))
fi

# ── GATE 4: Accessibility ────────────────────────────────
echo ""
echo "── Gate 4: Accessibility ──"
MISSING_ALT=$(grep -rn '<img' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | grep -v 'alt=' | wc -l | tr -d ' ')
if [ "$MISSING_ALT" -eq 0 ]; then
  echo "  PASS: All images have alt text"
  ((PASS++))
else
  echo "  WARN: $MISSING_ALT image(s) missing alt attribute"
  ((WARN++))
fi

BUTTON_COUNT=$(grep -rn '<button' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
ARIA_BUTTONS=$(grep -rn '<button' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | grep -c 'aria-label\|aria-labelledby\|>.\+<' 2>/dev/null || echo "0")
if [ "$BUTTON_COUNT" -eq 0 ] || [ "$ARIA_BUTTONS" -gt 0 ]; then
  echo "  PASS: Buttons have accessible labels"
  ((PASS++))
else
  echo "  WARN: Some buttons may lack accessible labels"
  ((WARN++))
fi

# ── GATE 5: Responsive Breakpoints ──────────────────────
echo ""
echo "── Gate 5: Responsive ──"
BP_COUNT=$(grep -rn 'className=' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | grep -c 'sm:\|md:\|lg:\|xl:' || echo "0")
if [ "$BP_COUNT" -gt 10 ]; then
  echo "  PASS: $BP_COUNT responsive breakpoints found"
  ((PASS++))
else
  echo "  WARN: Only $BP_COUNT responsive breakpoints — verify mobile layout"
  ((WARN++))
fi

# ── GATE 6: Code Hygiene ────────────────────────────────
echo ""
echo "── Gate 6: Hygiene ──"
CONSOLE_COUNT=$(grep -rn 'console\.\(log\|warn\|error\)' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CONSOLE_COUNT" -eq 0 ]; then
  echo "  PASS: No console statements"
  ((PASS++))
else
  echo "  WARN: $CONSOLE_COUNT console statement(s) — remove before shipping"
  ((WARN++))
fi

INLINE_COUNT=$(grep -rn 'style={{' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
if [ "$INLINE_COUNT" -le 2 ]; then
  echo "  PASS: Minimal inline styles ($INLINE_COUNT) — Tailwind-first"
  ((PASS++))
else
  echo "  WARN: $INLINE_COUNT inline style(s) — prefer Tailwind classes"
  ((WARN++))
fi

# Em-dash in UI copy — #1 AI-tell (anti-vibe-coded #23). Byte-safe pattern (U+2014),
# fires under the C locale a non-interactive shell inherits. ne-allow lines exempt.
EMDASH_COUNT=$(grep -rn $'\xe2\x80\x94' src/ --include="*.jsx" --include="*.tsx" 2>/dev/null | grep -v 'ne-allow' | wc -l | tr -d ' ')
if [ "${EMDASH_COUNT:-0}" -eq 0 ]; then
  echo "  PASS: No em-dash in UI copy (the #1 AI-tell)"
  ((PASS++))
else
  echo "  WARN: $EMDASH_COUNT em-dash(es) in copy — restructure or mark // ne-allow: em-dash"
  ((WARN++))
fi

# ── GATE 7: Bundle Size ─────────────────────────────────
echo ""
echo "── Gate 7: Bundle ──"
if [ -d "dist/assets" ]; then
  BUNDLE_KB=$(du -sk dist/assets/*.js 2>/dev/null | awk '{sum+=$1} END {print sum}')
  if [ "${BUNDLE_KB:-999}" -lt 300 ]; then
    echo "  PASS: ${BUNDLE_KB}KB JS bundle (under 300KB limit)"
    ((PASS++))
  else
    echo "  WARN: ${BUNDLE_KB}KB JS bundle — consider code splitting"
    ((WARN++))
  fi
else
  echo "  WARN: dist/ not found — run npm run build first"
  ((WARN++))
fi

# ── SUMMARY ──────────────────────────────────────────────
echo ""
echo "━━━ QUALITY GATE SUMMARY ━━━"
echo "  PASS: $PASS | WARN: $WARN | FAIL: $FAIL"
echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "VERDICT: SHIP IT"
  exit 0
else
  echo "VERDICT: FIX $FAIL FAILURE(S) BEFORE SHIPPING"
  exit 1
fi
