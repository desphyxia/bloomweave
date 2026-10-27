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
- Starting biomes: forest, meadow, wetland, rock.
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
- Tech (for later): three.js + TypeScript + Vite. Hex math, rules/scoring and
  rendering in separate modules; rules testable without a browser. Biomes,
  influence tables, bloom trios and pile composition are data (JSON).

## Draft rules (not yet confirmed)

- Draw the next trefoil from a finite pile and place it in an empty plot
  next to the map.
- Adjacent biomes spread influence (e.g. wetland feeds forest, rock shelters
  meadow).
- A vertex blooms when its three hexes form a complementary trio
  (e.g. forest + wetland + meadow). Blooms give points, bonus pieces and visuals.
- Run ends when the pile is empty; score unlocks new biomes over time.

## Open questions

### Geometry and placement
- Which vertex kinds can bloom? Proposal: blooms only at weave points;
  seams carry pairwise influence; the confluence is the piece's fixed
  identity and never blooms by itself.
- Can a trefoil repeat a biome (e.g. forest, forest, meadow)?
- Shape of the valley: unbounded, or a fixed valley outline made of plots?

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
| Mood | Cozy, pastoral | Cozy, restoration | Close (genre-typical) |

The pieces and matching rules are clearly different. The **economy loop**
(finite stack, earn more pieces by placing well, score unlocks content) is
currently Dorfromantik's loop almost exactly. To revisit.
