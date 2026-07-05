// Custom React Flow node, coloured by drift state. Read-only — clicking selects (to show
// provenance in the side panel); nothing here mutates the topology (Doctrine 05 P5).
//
// Phase 2: external_endpoint nodes are rendered by a SEPARATE branch (A3) that fires BEFORE the
// drift-state path — an external node is never in the drift overlay, so colouring it by overlay
// state would false-green a blind-spot (or fade it to 0.45 opacity). The external branch colours by
// classification, ALWAYS at full opacity (never faded), with a hollow+dashed+badged treatment for a
// blind-spot. The drift-state path below is unreachable for render_kind === "external".
import { Handle, Position } from "@xyflow/react";
import type { NodeProps } from "@xyflow/react";
import { STATE_VAR, EXTERNAL_VAR } from "./overlay";
import type { DriftState } from "./types";

export interface DriftNodeData {
  label: string;
  renderKind: string;
  classification?: string;     // external_endpoint only: supabase-rest|supabase-function|external-api|blind-spot
  state: DriftState;
  selected: boolean;
  [key: string]: unknown;
}

export default function DriftNode({ data }: NodeProps) {
  const d = data as DriftNodeData;

  // ── A3: external_endpoint branch — isolated from drift state, full opacity always ──
  if (d.renderKind === "external") {
    const blind = d.classification === "blind-spot";
    const colour = blind ? STATE_VAR.blind : EXTERNAL_VAR;   // amber for blind-spot, teal otherwise
    return (
      <div
        className={`topo-node node-external${blind ? " node-blindspot" : ""}${d.selected ? " selected" : ""}`}
        style={{
          borderColor: colour,
          opacity: 1,                                          // NEVER faded — a blind-spot must not retreat
          boxShadow: d.selected ? `0 0 0 2px ${colour}` : undefined,
        }}
      >
        <Handle type="target" position={Position.Top} style={{ opacity: 0 }} />
        <span className="topo-node-dot" style={{ background: colour }} />
        <div className="topo-node-body">
          <div className="topo-node-label">{d.label}</div>
          <div className="topo-node-kind">
            {blind ? <span className="topo-badge-blind" style={{ color: colour, borderColor: colour }}>blind spot</span>
                   : (d.classification ?? "external")}
          </div>
        </div>
        <Handle type="source" position={Position.Bottom} style={{ opacity: 0 }} />
      </div>
    );
  }

  // ── drift-state path (within-substrate nodes) ──
  const colour = STATE_VAR[d.state];
  const faded = d.state === "insync";
  return (
    <div
      className={`topo-node state-${d.state}${d.selected ? " selected" : ""}`}
      style={{
        borderColor: colour,
        opacity: faded ? 0.45 : 1,
        boxShadow: d.selected ? `0 0 0 2px ${colour}` : undefined,
      }}
    >
      <Handle type="target" position={Position.Top} style={{ opacity: 0 }} />
      <span className="topo-node-dot" style={{ background: colour }} />
      <div className="topo-node-body">
        <div className="topo-node-label">{d.label}</div>
        <div className="topo-node-kind">{d.renderKind}</div>
      </div>
      <Handle type="source" position={Position.Bottom} style={{ opacity: 0 }} />
    </div>
  );
}
