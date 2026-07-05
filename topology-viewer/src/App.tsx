import { useEffect, useMemo, useState, useCallback } from "react";
import {
  ReactFlow, ReactFlowProvider, Background, BackgroundVariant, Controls, MiniMap,
  MarkerType, useReactFlow,
} from "@xyflow/react";
import type { Edge, Node } from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import "./styles.css";

import type { Graph, GraphEdge, DriftOverlay, DriftState } from "./types";
import { buildStateIndex, isForeground, STATE_LABEL, STATE_VAR, edgeColour } from "./overlay";
import { layout, NODE_W, NODE_H } from "./layout";
import DriftNode from "./DriftNode";

const nodeTypes = { drift: DriftNode };

const SUMMARY_STATE: Record<string, DriftState> = {
  DRIFT: "drift", PARTIAL: "blind", UNVERIFIABLE: "unverifiable",
  INCONCLUSIVE: "unverifiable", IN_SYNC: "insync", "no-invariants-registered": "unverifiable",
};

const WITHIN_EDGE_STROKE = "rgba(140,140,150,0.35)";

// Phase 2 — the visual style of a render edge (single source of truth, mirrors the legend).
// within-system: faint grey, unchanged. cross-system: coloured by type (edgeColour), thicker, with an
// arrowhead. confidence drives solidity: declared-high solid, declared-medium dashed + dimmer,
// blind-spot amber + dashed (honesty boundary 1 made visual).
function edgeStyle(e: GraphEdge): React.CSSProperties {
  if (!e.cross_system) return { stroke: WITHIN_EDGE_STROKE };
  const stroke = edgeColour(e.type, e.confidence);
  if (e.confidence === "blind-spot") return { stroke, strokeWidth: 2, strokeDasharray: "5 4" };
  if (e.confidence === "declared-medium") return { stroke, strokeWidth: 1.6, strokeDasharray: "2 3", opacity: 0.85 };
  return { stroke, strokeWidth: 2.4 };   // declared-high (or any resolved cross-system edge)
}
// render-precedence concern: blind-spot must render LAST (on top) so amber is never hidden behind a
// solid edge on a parallel path (A7).
function concern(c: string | null): number {
  return c === "blind-spot" ? 3 : c === "declared-medium" ? 2 : c === "declared-high" ? 1 : 0;
}

async function loadJson<T>(url: string): Promise<T> {
  const r = await fetch(url);
  if (!r.ok) throw new Error(`${url}: ${r.status}`);
  return (await r.json()) as T;
}

function Inner() {
  const [graph, setGraph] = useState<Graph | null>(null);
  const [overlay, setOverlay] = useState<DriftOverlay | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showAll, setShowAll] = useState(false);          // drift-first by default
  const [crossSystemOnly, setCrossSystemOnly] = useState(false);  // Phase 2 filter (orthogonal)
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [positions, setPositions] = useState<Map<string, { x: number; y: number }>>(new Map());
  const { fitView, setCenter } = useReactFlow();

  useEffect(() => {
    Promise.all([loadJson<Graph>("/graph.json"), loadJson<DriftOverlay>("/drift-overlay.json")])
      .then(([g, o]) => { setGraph(g); setOverlay(o); })
      .catch((e) => setError(String(e)));
  }, []);

  const stateIndex = useMemo(
    () => (graph && overlay ? buildStateIndex(overlay, graph.nodes.map((n) => n.id)) : null),
    [graph, overlay],
  );

  // The set of external_endpoint node ids (used to make the neighbour walk treat them as TERMINAL — A6).
  const externalIds = useMemo(
    () => new Set((graph?.nodes ?? []).filter((n) => n.render_kind === "external").map((n) => n.id)),
    [graph],
  );
  const hasCrossSystem = useMemo(
    () => (graph?.edges ?? []).some((e) => e.cross_system),
    [graph],
  );

  // Which nodes are shown.
  //   crossSystemOnly → only cross-system edge endpoints.
  //   showAll         → everything.
  //   drift-first     → foreground (non-in-sync) + blind-spot externals (A4: always foreground) + 1-hop
  //                     neighbours, where external nodes are TERMINAL (A6: never expand a fan-in hub) +
  //                     every blind-spot edge is shown with BOTH endpoints (A4: never silently absent).
  const shownIds = useMemo(() => {
    if (!graph || !stateIndex) return new Set<string>();
    if (crossSystemOnly) {
      const s = new Set<string>();
      for (const e of graph.edges) if (e.cross_system) { s.add(e.source); s.add(e.target); }
      return s;
    }
    if (showAll) return new Set(graph.nodes.map((n) => n.id));

    const isBlindExternal = (id: string) => {
      const n = graph.nodes.find((x) => x.id === id);
      return !!n && n.render_kind === "external" && n.attributes?.classification === "blind-spot";
    };
    const fg = graph.nodes
      .filter((n) => isForeground(stateIndex.stateOf(n.id)) || isBlindExternal(n.id))
      .map((n) => n.id);
    const shown = new Set(fg);
    // 1-hop neighbour expansion for context — but do NOT expand THROUGH an external node (A6: a fan-in
    // hub would otherwise pull the whole codebase into the "cheap" drift-first view).
    for (const e of graph.edges) {
      if (shown.has(e.source) && !externalIds.has(e.source)) shown.add(e.target);
      if (shown.has(e.target) && !externalIds.has(e.target)) shown.add(e.source);
    }
    // A4: a blind-spot edge is ALWAYS shown with both endpoints, even when its in-system source is in
    // sync — a blind-spot must never silently vanish from the drift-first view (it IS the signal).
    for (const e of graph.edges) {
      if (e.confidence === "blind-spot") { shown.add(e.source); shown.add(e.target); }
    }
    return shown;
  }, [graph, stateIndex, showAll, crossSystemOnly, externalIds]);

  useEffect(() => {
    if (!graph || shownIds.size === 0) { setPositions(new Map()); return; }
    let cancelled = false;
    const ids = graph.nodes.filter((n) => shownIds.has(n.id)).map((n) => n.id);
    // in cross-system-only mode, lay out using only cross-system edges (so the layout reflects the filter)
    const layoutEdges = crossSystemOnly ? graph.edges.filter((e) => e.cross_system) : graph.edges;
    layout(ids, layoutEdges).then((pos) => { if (!cancelled) setPositions(pos); });
    return () => { cancelled = true; };
  }, [graph, shownIds, crossSystemOnly]);

  const rfNodes: Node[] = useMemo(() => {
    if (!graph || !stateIndex) return [];
    return graph.nodes
      .filter((n) => shownIds.has(n.id) && positions.has(n.id))
      .map((n) => ({
        id: n.id,
        type: "drift",
        position: positions.get(n.id)!,
        data: {
          label: n.label,
          renderKind: n.render_kind,
          classification: (n.attributes?.classification as string | undefined),
          state: stateIndex.stateOf(n.id),
          selected: n.id === selectedId,
        },
        width: NODE_W,
        height: NODE_H,
      }));
  }, [graph, stateIndex, shownIds, positions, selectedId]);

  const rfEdges: Edge[] = useMemo(() => {
    if (!graph) return [];
    // gate on positions too (not just shownIds) so an edge is never drawn in a frame where its endpoint
    // node has not yet been laid out — keeps edge/node visibility consistent during async ELK layout.
    const shown = graph.edges.filter(
      (e) => positions.has(e.source) && positions.has(e.target) && (!crossSystemOnly || e.cross_system),
    );
    // stable, content-derived ids (no index churn → no re-render flash); suffix duplicates on the same
    // source|type|target path so parallel edges keep distinct ids.
    const seen = new Map<string, number>();
    const withIds = shown.map((e) => {
      const base = `${e.source}|${e.type}|${e.target}`;
      const n = seen.get(base) ?? 0; seen.set(base, n + 1);
      return { e, id: n === 0 ? base : `${base}#${n}` };
    });
    // ascending concern → blind-spot edges last in the array → rendered on top (A7).
    withIds.sort((a, b) => concern(a.e.confidence) - concern(b.e.confidence));
    return withIds.map(({ e, id }) => {
      const colour = e.cross_system ? edgeColour(e.type, e.confidence) : WITHIN_EDGE_STROKE;
      return {
        id, source: e.source, target: e.target,
        style: edgeStyle(e),
        zIndex: e.cross_system ? concern(e.confidence) + 1 : 0,
        ...(e.cross_system ? { markerEnd: { type: MarkerType.ArrowClosed, color: colour, width: 14, height: 14 } } : {}),
        ...(crossSystemOnly && e.cross_system ? { label: e.type, labelStyle: { fontSize: 9, fill: "var(--text-dim)" }, labelBgStyle: { fill: "var(--panel)", fillOpacity: 0.7 } } : {}),
      } as Edge;
    });
  }, [graph, positions, crossSystemOnly]);

  useEffect(() => {
    if (rfNodes.length > 0) {
      const t = setTimeout(() => fitView({ duration: 300, padding: 0.2 }), 50);
      return () => clearTimeout(t);
    }
  }, [rfNodes.length, fitView]);

  const onNodeClick = useCallback((_: unknown, n: Node) => setSelectedId(n.id), []);
  const focusNode = useCallback((id: string) => {
    setSelectedId(id);
    const p = positions.get(id);
    if (p) setCenter(p.x + NODE_W / 2, p.y + NODE_H / 2, { zoom: 1.2, duration: 400 });
  }, [positions, setCenter]);

  if (error) return <div className="topo-fatal">Could not load the drift map.<br /><code>{error}</code><br /><br />Run the build step first (see the viewer README).</div>;
  if (!graph || !overlay || !stateIndex) return <div className="topo-loading">Loading the drift map…</div>;

  const summaryState = SUMMARY_STATE[overlay.summary] ?? "unverifiable";
  const rankedActions = Object.entries(overlay.actions).sort((a, b) => b[1].impact_rank - a[1].impact_rank);
  const labelOf = (id: string) => graph.nodes.find((n) => n.id === id)?.label ?? id;
  const selected = selectedId ? graph.nodes.find((n) => n.id === selectedId) : null;
  const blindDims = Object.entries(graph.coverage.emitters).filter(([, v]) => v !== "covered");
  const stale = graph.source_last_updated
    ? (Date.now() - Date.parse(graph.source_last_updated)) > 48 * 3600 * 1000
    : false;

  // A1: the persistent "cross-system coverage is partial" chip. Verdict read LIVE from coverage state +
  // the blind-spot-edge signal — never hardcoded. Fires when ANY contributing signal says incomplete:
  //   any emitter not covered · empty coverage map · any declared-missing emitter · any blind-spot edge.
  const coverageEntries = Object.entries(graph.coverage.emitters);
  const crossSystemPartial =
    coverageEntries.length === 0 ||
    coverageEntries.some(([, v]) => v !== "covered") ||
    graph.coverage.missing_emitters.length > 0 ||
    graph.has_blind_spot_edges === true ||
    // defense-in-depth: never depend on the single optional envelope field — re-derive from the edges
    // (a stale/older graph.json that omits has_blind_spot_edges still surfaces the chip).
    graph.edges.some((e) => e.confidence === "blind-spot");

  // incident cross-system edges for the selected node (side-panel derivation — A13)
  const incidentXS: GraphEdge[] = selected
    ? graph.edges.filter((e) => e.cross_system && (e.source === selected.id || e.target === selected.id))
    : [];

  const crossSystemEmpty = crossSystemOnly && !hasCrossSystem;

  return (
    <div className="topo-root">
      <aside className="topo-panel">
        <header className="topo-head">
          <div className="topo-entity">{graph.entity}</div>
          <span className="topo-pill" style={{ background: STATE_VAR[summaryState] }}>{overlay.summary}</span>
        </header>

        <div className="topo-freshness">
          <span className={stale ? "stale" : ""}>{stale ? "⚠ stale · " : ""}source {graph.source_last_updated ?? "unknown"}</span>
        </div>

        {crossSystemPartial && (
          <div className="topo-xsystem-chip">
            Cross-system coverage is partial — some wiring may be unseen or shown as an amber blind spot.
          </div>
        )}

        <label className="topo-toggle">
          <input type="checkbox" checked={showAll} disabled={crossSystemOnly}
                 onChange={(e) => setShowAll(e.target.checked)} />
          Show all nodes ({graph.nodes.length}) — off = drift-first
        </label>
        <label className="topo-toggle">
          <input type="checkbox" checked={crossSystemOnly}
                 onChange={(e) => setCrossSystemOnly(e.target.checked)} />
          Cross-system edges only
        </label>

        <section>
          <h3>Drift ({overlay.driftCount}) — ranked by impact</h3>
          {rankedActions.length === 0 && <p className="topo-empty">No drift. The blind-spots below are still worth a look.</p>}
          {rankedActions.map(([id, a]) => (
            <button key={id} className="topo-driftrow" onClick={() => focusNode(id)}>
              <div className="topo-driftrow-top">
                <span className="dot" style={{ background: STATE_VAR.drift }} />
                <span className="topo-driftrow-label">{labelOf(id)}</span>
                <span className="topo-action">{a.named_action}</span>
              </div>
              <div className="topo-driftrow-meta">
                impact {a.impact_rank}{a.rank_completeness === "partial" ? " (partial)" : ""}
                {a.reason ? ` · ${a.reason}` : ""}
              </div>
              <div className="topo-prov">{a.provenance}</div>
            </button>
          ))}
        </section>

        {blindDims.length > 0 && (
          <section>
            <h3>Blind spots — we can't see here</h3>
            {blindDims.map(([name, cov]) => (
              <div key={name} className="topo-chip" style={{ borderColor: STATE_VAR.blind }}>
                {name}: {cov}
              </div>
            ))}
            {graph.coverage.missing_emitters.map((m, i) => (
              <div key={m.name ?? `missing-${i}`} className="topo-chip" style={{ borderColor: STATE_VAR.blind }}>
                {(m.name ?? "(unnamed)")}: not introspected
              </div>
            ))}
          </section>
        )}

        <section className="topo-legend">
          <h3>Legend — drift</h3>
          {(["drift", "blast", "blind", "unverifiable", "insync"] as DriftState[]).map((s) => (
            <div key={s} className="topo-legend-row">
              <span className="dot" style={{ background: STATE_VAR[s] }} />
              {STATE_LABEL[s]} <span className="topo-count">({stateIndex.counts[s]})</span>
            </div>
          ))}
          <h3>Legend — cross-system</h3>
          {([["reads_from", "reads"], ["writes_to", "writes"], ["invokes", "invokes"], ["calls", "calls"]] as Array<[string, string]>).map(([t, lbl]) => (
            <div key={t} className="topo-legend-row">
              <span className="swatch-line" style={{ borderColor: edgeColour(t, null) }} />
              {lbl}
            </div>
          ))}
          <div className="topo-legend-row">
            <span className="swatch-line dashed" style={{ borderColor: STATE_VAR.blind }} />
            blind spot (unresolved — dashed amber)
          </div>
        </section>

        {selected && (
          <section className="topo-selected">
            <h3>{selected.label}</h3>
            <div className="topo-kv"><span>kind</span><span>{selected.kind} · {selected.render_kind}</span></div>
            {selected.render_kind === "external" ? (
              <>
                <div className="topo-kv"><span>classification</span><span>{String(selected.attributes?.classification ?? "external")}</span></div>
                {selected.attributes?.url_host ? <div className="topo-kv"><span>host</span><span>{String(selected.attributes.url_host)}</span></div> : null}
                {selected.attributes?.url_path_template ? <div className="topo-kv"><span>path</span><span>{String(selected.attributes.url_path_template)}</span></div> : null}
                {selected.attributes?.method ? <div className="topo-kv"><span>method</span><span>{String(selected.attributes.method)}</span></div> : null}
              </>
            ) : (
              <>
                <div className="topo-kv"><span>emitter</span><span>{selected.emitter}</span></div>
                <div className="topo-kv"><span>state</span><span>{STATE_LABEL[stateIndex.stateOf(selected.id)]}</span></div>
              </>
            )}
            <div className="topo-kv"><span>source</span><span className="topo-prov">{selected.source}</span></div>
            {incidentXS.length > 0 && (
              <>
                <h3 style={{ marginTop: 10 }}>Cross-system wiring</h3>
                {incidentXS.map((e, i) => (
                  <div key={`xs-${i}`} className="topo-chip" style={{ borderColor: edgeColour(e.type, e.confidence) }}>
                    {e.source === selected.id ? "→ " : "← "}
                    {labelOf(e.source === selected.id ? e.target : e.source)} · {e.type} · {e.confidence}
                    {e.attributes && (e.attributes as Record<string, unknown>).derivation
                      ? <div className="topo-prov">{String((e.attributes as Record<string, unknown>).derivation)}</div>
                      : null}
                  </div>
                ))}
              </>
            )}
          </section>
        )}

        <footer className="topo-foot">
          Read-only view · the substrate is the source of truth · generated {overlay.generatedAt}
        </footer>
      </aside>

      <main className="topo-canvas">
        {crossSystemEmpty && (
          <div className="topo-canvas-msg">
            No cross-system edges in this substrate — this is expected if the external-api-graph emitter
            has not yet run. Check the coverage panel.
          </div>
        )}
        <ReactFlow
          nodes={rfNodes}
          edges={rfEdges}
          nodeTypes={nodeTypes}
          onNodeClick={onNodeClick}
          nodesDraggable={false}
          nodesConnectable={false}
          elementsSelectable
          fitView
          minZoom={0.05}
          maxZoom={2.5}
          proOptions={{ hideAttribution: true }}
        >
          <Background variant={BackgroundVariant.Dots} gap={22} size={1} color="rgba(120,120,130,0.18)" />
          <Controls showInteractive={false} />
          <MiniMap pannable zoomable nodeStrokeWidth={2} />
        </ReactFlow>
      </main>
    </div>
  );
}

export default function App() {
  return (
    <ReactFlowProvider>
      <Inner />
    </ReactFlowProvider>
  );
}
