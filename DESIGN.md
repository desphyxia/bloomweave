# Bloomweave — Design Doc

_Living document. Updated as decisions are made during design sessions._

## Pitch

A calm, single-player hex tile-placement game with a textile look. The player
restores a valley, shaped like a quilt, by placing **trefoils** (three hexes
meeting at one vertex) into fixed trefoil-shaped plots. Biomes sit on whole
hexes; corners where three pieces bring together the right trio of biomes
**bloom**, and chains of linked blooms become **wildlife corridors** that
animals move into. No combat, no timers.

### Core loop (one turn)
1. Look at the current piece (and the next one).
2. Optionally spend seeds: set the piece aside, swap it with the next one, or
   look further ahead.
3. Choose an empty plot and one of the piece's arrangements (up to 6).
4. Completed corners are checked: matching trios bloom (+1 seed each, new
   trios go into the journal), good pairs at seams show small signs of life,
   and corridors grow; animals settle when their needs are met.
5. When every plot is filled, the valley is restored and scored.

The decision each turn: which plot, and which arrangement, best completes
blooms now while keeping corridor routes and future corners open.

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
  - First valley: forest, meadow, wetland, **heath** (purple heather and
    gorse). Heath replaced rock from the original draft, which felt boring;
    rock may return later in a livelier form (e.g. mossy stone).
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
  journal. Each bloom gives 1 seed (see Seeds).
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
- **Wildlife corridors are the large-scale goal** (instead of Dorfromantik's
  biome regions or rivers). They connect **blooms**, not tiles.
  - Two blooms are linked when they share a hex. A corridor is a chain of
    linked blooms of any length; it can branch and loop. Each bloom can link
    to up to 3 others.
  - Animals settle along corridors; some want a certain length or certain
    bloom kinds.
  - **Trails follow hex borders.** On every hex the two weave points are two
    border edges apart, with one seam corner between them, and both edges lie
    on a border between two pieces. So each link is drawn as a 2-edge trail
    (weave point → seam → weave point) running along piece outlines.
  - Rejected: biome regions (too close to Dorfromantik), no large-scale goal
    (risk of samey play).
- **Game modes.** Start with **Valley mode**: each valley has a fixed outline
  made of plots, and you get exactly enough pieces to fill it. The run ends
  when the valley is fully restored; every run in a valley has the same
  length, and the score measures quality (blooms, corridors, discoveries),
  not how long you lasted. Blooms earn *choice*, not extra pieces. An
  **open mode** (map grows until the pile runs out) may come later as a
  second mode.
- **Seeds are the bloom currency.** Each bloom gives 1 seed. You always see
  the current piece and the next one. Spend seeds to: set the current piece
  aside in a single reserve slot; swap the current piece with the next one;
  or see the next 3 pieces for one turn. Leftover seeds count a little
  toward the final score. Valley size is fixed, so seeds improve the valley
  without making runs longer. Exact seed costs are open.
- **Progression through discoveries, not score.** New blooms go into the
  journal the first time a trio is made; animals settled by corridors are
  recorded too. Discoveries unlock new valleys, biomes and valley variants
  (e.g. settling otters opens a river valley; finding every bloom in a valley
  reveals a hidden variant). Score stays as a personal best per valley.
- **Influence is visual only (for now).** Where two pieces meet at a seam,
  good biome pairs show small signs of life (taller trees by wetland,
  heather creeping into meadow beside heath). No effect on rules or score.
  Pairs are defined in a data table so they can gain rules later.
  - *Recorded for later:* influence as a full mechanic, where pairs change
    hexes (e.g. forest next to wetland becomes "lush forest", which can make
    special blooms). Revisit if playtests show the game lacks depth.
- **Run length grows with progress.** First valleys are small (~20 plots,
  ~5–8 min). Later valleys grow to 30–45 plots (~10–20 min). Larger games
  are also wanted: big valleys (60+ plots) as an option, and the open mode
  later. Every valley can be paused and resumed at any time.
- **Animals: residents plus a hidden visitor.** Each valley shows its 2–4
  resident animals and their needs before the first piece (e.g. "Otters: a
  5-bloom corridor touching wetland"). One hidden visitor also settles if a
  secret pattern gets built, which feeds the journal and replays. All animal
  goals are optional; missing one only means that animal doesn't move in
  this time. (Rejected: pop-up requests during a run, too close to
  Dorfromantik's quests.)
- **Placement and start.** Each piece must touch a piece already placed, so
  the valley grows outward like restoration spreading. Every valley starts
  from a fixed **landmark piece** in its centre: three different biomes from
  that valley, with a landmark at its confluence (an old tree, a spring). It
  follows the normal rules but is the valley's heart.
- **Same-biome trios don't bloom in the prototype.** Only all-different trios
  bloom for now; revisit later.
- **Atmosphere.**
  - *Visual style: textile / embroidery.* Pieces are fabric patches (forest =
    soft felt, meadow = linen, wetland = shimmering silk, heath = purple tweed);
    piece borders are stitched seams; corridors are embroidered thread along
    those seams; blooms are embroidered flowers; animals are small woven
    figures. The valley reads as a quilt coming to life.
  - *Camera:* tilted 3D view with free orbit and zoom.
  - *Sound:* soft ambient music; each biome adds nature sounds that layer up
    as the valley fills; fabric rustle on placement.
  - *Feedback:* blooms and settling animals use short, gentle animations that
    never interrupt; the player can keep placing straight away.
- Tech (for later): three.js + TypeScript + Vite. Hex math, rules/scoring and
  rendering in separate modules; rules testable without a browser. Biomes,
  influence tables, bloom trios and pile composition are data (JSON).

## Open questions

### Geometry and placement
- Valley outlines: shape, and whether outlines include obstacles such as a
  lake or cliff.
- Which landmark each valley has.

### Biomes and valleys
- Are valleys hand-made (a curated list of biome mixes) or generated (a
  random mix each run)?
- Same-biome blooms (e.g. three forests = "deep wood") after the prototype?
- Content load: 8 biomes = 56 possible all-different trios. Do all of them
  need a bloom, or only the trios that appear in the valleys we ship?

### Wildlife corridors
- Should a trail's path matter to the rules? Proposal: no, for now; it's
  only how the trail is drawn. Possible later twist: animals prefer trails
  that run between *different* biomes (edge habitat), so the biomes on
  either side of the trail would matter too.

### Scoring and economy
- How blooms, corridors and discoveries turn into a final score.
- Seed costs for each action, and whether the reserve slot can grow.

### Biome interactions
- Which pairs count as good pairs, and what each looks like.

### Requests / goals
- What each animal asks for (corridor length, bloom kinds, biomes touched)
  and what settling it gives (score, seeds, journal entry).
- How hidden visitors are hinted at, if at all.

### Difficulty and run length
- How large games are offered: big valleys unlocked by discoveries, a
  size option per valley, or both.
- Difficulty curve across valleys (piece mix, valley shape, animal needs).

### Progression and unlocks
- The unlock map: which discoveries open which valleys, biomes and variants.

### Atmosphere
- Exact fabric and stitch look in three.js (materials, outlines, puffiness).
- Music direction and how biome sounds layer.

## Dorfromantik comparison

| Area | Dorfromantik | Bloomweave (current draft) | Risk |
|---|---|---|---|
| Tile | Single hex, 6 edge segments | Trefoil of 3 whole-hex biomes | Distinct |
| Matching | Edges match edges | Trios meet at vertices | Distinct |
| Run end | Stack runs out | Valley mode: valley is full. Open mode (later): pile runs out | Distinct (Valley); **Close** (Open) |
| Extending the run | Perfect placements and quests add tiles | Valley mode: blooms earn choice, not pieces | Distinct (Valley) |
| Meta | Score unlocks tiles and biomes | Discoveries (blooms, animals) unlock valleys and biomes | Distinct |
| Terrain set | One fixed set of terrain types in every run | Different biome mix per valley | Distinct |
| Board | Freeform single hexes | Fixed grid of trefoil plots | Distinct |
| Mood | Cozy, pastoral | Cozy, restoration | Close (genre-typical) |
| Look | Soft low-poly 3D, model-railway feel | Textile / embroidered quilt | Distinct |

Pieces, matching, board and terrain sets are clearly different. Valley mode
replaces Dorfromantik's economy loop (finite stack, earn more tiles by placing
well). An open mode would bring that loop back, so it needs its own twist
before it's built. Progression through discoveries replaces score-based unlocks.

## Prototype scope (agreed, not started)

- One valley: about 20 plots, fixed outline, first-valley biomes.
- Piece list from JSON: mostly three-different pieces plus some doubles.
- Place, rotate and mirror with a preview of which corners would bloom.
- The 4 named blooms (data-driven); seeds with set aside, swap, look ahead.
- Corridors drawn along piece borders; 2 resident animals with simple needs.
- Simple end screen with the score.
- Simple coloured 3D hexes with orbit camera (textile look later).
- Rules in their own module with unit tests: hex math, plot lookup, corner
  lookup, bloom checks, corridor finding.
- Later: journal and unlocks, hidden visitor, sound, textile shaders,
  influence visuals, open mode.
