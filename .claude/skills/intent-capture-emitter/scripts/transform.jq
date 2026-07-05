# intent-capture-emitter/scripts/transform.jq — raw extraction -> the Doctrine 04 §6.1 record.
#
# Input (stdin): one raw extraction object from extract.mjs.
# Args: --arg source_commit <sha>  --arg timestamp <iso>  (resolved by emit.sh from git)
# Output: a single 14-field intent record (the §6.1 shape), ready for intent-store.sh bulk-write.
#
# Discipline:
#  - id is DERIVED from stable source identity (kind + source_file slug) -- council Gate 1.
#  - wired_to defaults to "pending" -- NEVER guessed from prose (D2 / council G1). An operator
#    authors a real wired_to in the carrier later; the parser never invents one.
#  - falsifier is set to null -- a prose Element-4 candidate is NOT auto-promoted (NSF-2 rejects
#    prose; converting prose -> machine-executable is an authoring act the parser must not do).
#    The prose candidate is preserved under .diagnostics for the operator, OUTSIDE the record.
#  - status maps the define-destination vocabulary to the closed intent enum (P6).

# define-destination status -> intent status enum
def map_status($s):
  ($s // "" | ascii_downcase) as $d
  | if   ($d | test("draft"))     then "draft"
    elif ($d | test("confirmed")) then "accepted"
    elif ($d | test("accepted"))  then "accepted"
    elif ($d | test("superseded")) then "superseded"
    elif ($d | test("fulfilled")) then "fulfilled"
    else "draft" end;

def slug($s): ($s // "x") | gsub("[^A-Za-z0-9]+"; "-") | gsub("(^-+|-+$)"; "") | ascii_downcase;

# kind -> emitter (the store closed enum is destination_parser/adr_parser/roadmap_parser/contract_parser).
# NOT kind+"_parser" naively: kind "roadmap_item" maps to "roadmap_parser", not "roadmap_item_parser".
def emitter_for($k):
  if   $k == "destination"  then "destination_parser"
  elif $k == "adr"          then "adr_parser"
  elif $k == "roadmap_item" then "roadmap_parser"
  elif $k == "contract"     then "contract_parser"
  else "manual" end;

. as $raw
| {
    record: {
      id:                 ("intent:" + $raw.kind + ":" + slug($raw.source_file)),
      kind:               $raw.kind,
      source_file:        $raw.source_file,
      source_commit:      $source_commit,
      timestamp:          $timestamp,
      title:              $raw.title,
      status:             map_status($raw.status_raw),
      superseded_by:      null,
      conditions:         $raw.conditions,
      binary_test:        $raw.binary_test,
      falsifier:          null,
      wired_to:           "pending",
      owner:              ($raw.owner_raw // null),
      acceptance_cadence: null,
      emitter:            emitter_for($raw.kind)
    },
    diagnostics: {
      prose_falsifier_candidate: $raw.falsifier_candidate,
      note: (if $raw.falsifier_candidate != null
             then "Element-4 prose present -- convert to a machine-executable falsifier (D04 §6.1.1); NOT auto-promoted (D2/NSF-2)."
             else "no falsifier candidate found in carrier" end),
      wired_to_note: "wired_to=pending -- no machine wiring authored in the carrier; never guessed (D2)."
    }
  }
