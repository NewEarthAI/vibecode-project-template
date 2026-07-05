// The node-flag -> drift-state machinery (design §4.1). The transform already applies precedence,
// but we re-apply it defensively here so the viewer can never colour a drifted node grey/faded.
import type { DriftOverlay, DriftState } from "./types";

export const STATE_LABEL: Record<DriftState, string> = {
  drift: "Drift",
  blast: "Blast radius",
  blind: "Blind spot",
  unverifiable: "Unverifiable",
  insync: "In sync",
};

// CSS custom properties — kept in one place so the colours live in styles.css.
export const STATE_VAR: Record<DriftState, string> = {
  drift: "var(--topo-drift)",
  blast: "var(--topo-blast)",
  blind: "var(--topo-blind)",
  unverifiable: "var(--topo-unverifiable)",
  insync: "var(--topo-insync)",
};

// Phase 2 — cross-system edge colours, keyed by edge type. Mirrors STATE_VAR (one place; the values
// live in styles.css :root). An unknown/future edge type degrades to the generic cross-system colour
// (never a null stroke → never an invisible edge). Blind-spot edges override this with the amber
// --topo-blind regardless of type (honesty boundary 1).
export const EDGE_TYPE_VAR: Record<string, string> = {
  reads_from: "var(--topo-edge-reads_from)",
  writes_to: "var(--topo-edge-writes_to)",
  invokes: "var(--topo-edge-invokes)",
  calls: "var(--topo-edge-calls)",
};
export const EDGE_XSYSTEM_FALLBACK = "var(--topo-edge-xsystem)";
// Neutral colour for a resolved (non-blind-spot) external_endpoint node.
export const EXTERNAL_VAR = "var(--topo-external)";

// The visual style of a render edge — single source of truth for the canvas + the legend.
export function edgeColour(type: string, confidence: string | null): string {
  if (confidence === "blind-spot") return STATE_VAR.blind;        // amber, always — never type-coloured
  return EDGE_TYPE_VAR[type] ?? EDGE_XSYSTEM_FALLBACK;            // unknown type → generic, never null
}

export interface StateIndex {
  stateOf: (id: string) => DriftState;
  counts: Record<DriftState, number>;
}

// Build an id -> state lookup once, applying precedence by set membership.
export function buildStateIndex(overlay: DriftOverlay, allIds: string[]): StateIndex {
  const drift = new Set(overlay.driftNodeIds);
  const blast = new Set(overlay.blastRadiusNodeIds);
  const blind = new Set(overlay.blindSpotNodeIds);
  const unver = new Set(overlay.unverifiableNodeIds);

  const stateOf = (id: string): DriftState => {
    if (drift.has(id)) return "drift";
    if (blast.has(id)) return "blast";
    if (blind.has(id)) return "blind";
    if (unver.has(id)) return "unverifiable";
    return "insync";
  };

  const counts: Record<DriftState, number> = {
    drift: 0, blast: 0, blind: 0, unverifiable: 0, insync: 0,
  };
  for (const id of allIds) counts[stateOf(id)] += 1;

  return { stateOf, counts };
}

// A node is "actionable" (foreground in the drift-first default view) when it is anything but in-sync.
export const isForeground = (s: DriftState): boolean => s !== "insync";
