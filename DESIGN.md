# Bloomweave — Design Doc

_Living document. Updated as decisions are made during design sessions._

## Pitch

A calm, single-player hex tile-placement game. The player restores a valley by
placing **trefoils** (three hexes meeting at one vertex) on a flat-top hex grid.
Biomes sit on whole hexes, and vertices where three complementary biomes meet
**bloom** into flowers and wildlife. No combat, no timers.

---

## Decided

- Single-player, calm, no combat, no timers.
- Flat-top hex grid, axial coordinates.
- Pieces are trefoils: three hexes around one shared vertex (the "confluence").
- Biomes belong to whole hexes, not edges (a deliberate difference from
  Dorfromantik's edge matching).
- **Biomes per valley.** The game has a larger collection of biomes (roughly
  8–10 over the whole game), but each valley (run) uses only a mix of 4–5.
  Biomes recur across valleys alongside different partners, so a known biome
  takes part in new trios and new blooms. Reason: 4–5 biomes keep a run
  readable (4 biomes = 4 all-different trios, 5 = 10; 6 would be 20, too many
  to plan around), while the larger collection gives variety between runs.
  - First valley: forest, meadow, wetland, rock (from the original draft).
- **Fixed plot grid (no holes).** The grid is pre-split into trefoil-shaped
  plots, and every piece fills exactly one whole plot, so holes can't happen.
  - Hex `(q,r)` belongs to the plot whose base `(q0,r0)` has
    `q0 ≡ r0 (mod 3)`; the plot is base + offsets `(0,0)`, `(1,0)`, `(0,1)`.
    With `c = (q − r) mod 3`, the base is `(q,r)` minus offset `c`.
  - Each plot borders 6 other plots, so the plots form a hex-like grid of
    their own.
  - Placement = choose an empty plot next to the map + one of 6 biome
    arrangements (3 rotations × mirror). Mirroring is across the piece's own
    symmetry axis, so the shape never changes.
  - Three kinds of vertex. Each plot touches 1 **confluence** (inside the
    piece), 6 **seams** (two plots: 2 hexes from one, 1 from the other) and
    6 **weave points** (three different plots).
  - Rejected: more 3-hex shapes (still leave holes), single-hex fillers and
    gaps that heal by themselves (soften holes but don't prevent them).
- **Blooms.** Only weave points can bloom. A weave point is
  checked the moment its third plot is filled; if its three biomes form a
  bloom trio, it blooms at once and stays bloomed for good. Each trio is a
  named bloom with its own look (e.g. forest + wetland + meadow = fern hollow
  with frogs), listed in a data table. **A trio makes the same bloom in every
  valley**, so knowledge carries over and blooms can be collected in a
  journal. Rewards (points, bonus pieces) are still open.
  - A new piece completes one weave point for each pair of filled
    neighbouring plots that sit next to each other around it: 0 when it
    touches a single neighbour, 1–2 on a typical edge of the map, up to 6
    when it fills the last gap. This pulls the player toward a compact valley.
  - While a piece is being placed, the game can preview which corners would
    bloom with each orientation.
- **Pieces can repeat biomes, and that is the main difficulty setting.**
  Three different biomes = 6 distinct placements; two the same + one
  different = 3; all three the same = 1. Early valleys mostly use
  three-different pieces; later valleys use more doubles; all-same pieces are
  rare. Each valley's data file sets the proportions of each piece type.
- Tech (for later): three.js + TypeScript + Vite. Hex math, rules/scoring and
  rendering in separate modules; rules testable without a browser. Biomes,
  influence tables, bloom trios and pile composition are data (JSON).

## Draft rules (not yet confirmed)

- Draw the next trefoil from a finite pile and place it in an empty plot
  next to the map.
- Adjacent biomes spread influence (e.g. wetland feeds forest, rock shelters
  meadow).
- Run ends when the pile is empty; score unlocks new biomes over time.

## Open questions

### Geometry and placement
- Seams carry pairwise influence and the confluence never blooms by itself
  (proposal; details under Biome interactions).
- Shape of the valley: unbounded, or a fixed valley outline made of plots?

### Biomes and valleys
- Are valleys hand-made (a curated list of biome mixes) or generated (a
  random mix each run)?
- Can some same-biome trios bloom too (e.g. three forests = "deep wood")?
- Content load: 8 biomes = 56 possible all-different trios. Do all of them
  need a bloom, or only the trios that appear in the valleys we ship?

### Core loop
- What makes each placement a real decision?

### Scoring and economy
- How blooms score; how bonus pieces are earned; how to keep a run's length
  from snowballing.

### Biome interactions
- What "influence" does mechanically, and whether it overlaps with blooms.

### Requests / goals
- Optional goals: form, frequency, rewards.

### Difficulty and run length
- Target session length; how pile size and difficulty scale.

### Progression and unlocks
- What score unlocks, and whether unlocks add depth or just variety.

### Atmosphere
- Visual style, sound, pacing.

## Dorfromantik comparison

| Area | Dorfromantik | Bloomweave (current draft) | Risk |
|---|---|---|---|
| Tile | Single hex, 6 edge segments | Trefoil of 3 whole-hex biomes | Distinct |
| Matching | Edges match edges | Trios meet at vertices | Distinct |
| Run end | Stack runs out | Pile runs out | **Close** |
| Extending the run | Perfect placements and quests add tiles | Blooms add bonus pieces | **Close** |
| Meta | Score unlocks tiles and biomes | Score unlocks biomes | **Close** |
| Terrain set | One fixed set of terrain types in every run | Different biome mix per valley | Distinct |
| Board | Freeform single hexes | Fixed grid of trefoil plots | Distinct |
| Mood | Cozy, pastoral | Cozy, restoration | Close (genre-typical) |

The pieces and matching rules are clearly different. The **economy loop**
(finite stack, earn more pieces by placing well, score unlocks content) is
currently Dorfromantik's loop almost exactly. To revisit.
