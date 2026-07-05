// ELK layered layout (design §2.1). For the prototype we run a single ELK pass over whatever node
// set is currently shown — which in the drift-first default is the SMALL actionable subset, so the
// default layout is cheap regardless of total graph size. "Show all" is the opt-in heavy path.
import ELK from "elkjs/lib/elk.bundled.js";

// elkjs ships loose types for the bundled entry; declare just what we use.
interface ElkPositioned { id: string; x?: number; y?: number; children?: ElkPositioned[] }
interface ElkLike { layout: (g: unknown) => Promise<ElkPositioned> }

const elk = new (ELK as unknown as { new (): ElkLike })();

export const NODE_W = 190;
export const NODE_H = 56;

export interface LaidOut { x: number; y: number }

export async function layout(
  nodeIds: string[],
  edges: Array<{ source: string; target: string }>,
): Promise<Map<string, LaidOut>> {
  const present = new Set(nodeIds);
  const elkGraph = {
    id: "root",
    layoutOptions: {
      "elk.algorithm": "layered",
      "elk.direction": "DOWN",
      "elk.layered.spacing.nodeNodeBetweenLayers": "90",
      "elk.spacing.nodeNode": "55",
      "elk.layered.crossingMinimization.strategy": "LAYER_SWEEP",
      "elk.edgeRouting": "ORTHOGONAL",
    },
    children: nodeIds.map((id) => ({ id, width: NODE_W, height: NODE_H })),
    // only edges whose endpoints are both in the shown set (keeps ELK consistent on filtered views)
    edges: edges
      .filter((e) => present.has(e.source) && present.has(e.target))
      .map((e, i) => ({ id: `e${i}`, sources: [e.source], targets: [e.target] })),
  };

  const res = await elk.layout(elkGraph);
  const pos = new Map<string, LaidOut>();
  for (const c of res.children ?? []) pos.set(c.id, { x: c.x ?? 0, y: c.y ?? 0 });
  return pos;
}
