// Types for the two render-target-agnostic JSON contracts.
// Authority: ../.claude/skills/topology-visual-emitter/references/{graph-shape,drift-overlay-shape}.md

export type Category = "data" | "automation" | "code" | "config" | "external";
export type RenderKind =
  | "table" | "schema" | "function" | "service" | "policy" | "group" | "code" | "config" | "node"
  | "external";

export interface GraphNode {
  id: string;
  kind: string;
  render_kind: RenderKind;
  category: Category;
  label: string;
  emitter: string;
  coverage: string;
  layer: string;
  source: string;
  attributes: Record<string, unknown>;
}

export interface GraphEdge {
  source: string;
  target: string;
  type: string;
  weight: number;
  // Phase 2 (cross-system render layer). cross_system = endpoints in different layers OR the edge
  // carries a confidence attribute. confidence is null on within-system edges; on a cross-system edge
  // it is one of declared-high|declared-medium|blind-spot (unknown confidence is forced to blind-spot
  // upstream in graph-transform.jq — never green). attributes carries {derivation, confidence} on
  // cross-system edges, null on within-system edges (never {}).
  cross_system: boolean;
  confidence: string | null;
  attributes?: Record<string, unknown> | null;
}

export interface Layer {
  id: string;
  name: string;
  category: Category;
  nodeIds: string[];
}

export interface Coverage {
  emitters: Record<string, string>;
  missing_emitters: Array<{ name: string; reason: string }>;
}

export interface Graph {
  schema_version: string;
  entity: string;
  generated_at: string;
  source_last_updated: string | null;
  coverage: Coverage;
  // Phase 2: true when any rendered edge is a blind-spot — a fail-safe chip signal independent of the
  // emitter-coverage envelope (an all-`covered` substrate can still carry blind-spot edges).
  has_blind_spot_edges?: boolean;
  nodes: GraphNode[];
  edges: GraphEdge[];
  layers: Layer[];
  parent_map: Record<string, string[]>;
  child_map: Record<string, string[]>;
}

export interface DriftAction {
  named_action: string;
  impact_rank: number;
  rank_completeness: "complete" | "partial";
  reason: string | null;
  provenance: string;
  source_of_truth_ref: string | null;
}

export interface DriftOverlay {
  version: string;
  generatedAt: string;
  entity: string;
  summary: string;
  driftCount: number;
  driftNodeIds: string[];
  blastRadiusNodeIds: string[];
  blastRadiusPartial: boolean;
  blindSpotNodeIds: string[];
  unverifiableNodeIds: string[];
  actions: Record<string, DriftAction>;
}

// The five drift states (design §4.1). Precedence: drift > blast > blind > unverifiable > insync.
export type DriftState = "drift" | "blast" | "blind" | "unverifiable" | "insync";
