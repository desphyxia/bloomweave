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
- **Blooms are made as needed.** Of the 56 all-different trios (8 biomes),
  only those used by shipped levels or regions get a named bloom; content
  grows with the levels. Custom mode only offers biome mixes whose trios
  all have blooms.
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
- **Pieces can repeat biomes, for variety.** Three different biomes = 6
  distinct placements; two the same + one different = 3; all three the same
  = 1. Each valley's data file sets the proportions of each piece type.
  (Originally meant as the main difficulty setting, but the balance sim
  showed more doubles make blooms slightly *easier*, so it isn't.)
- **Difficulty comes from each valley's bloom rules:** whether order
  matters, which trios bloom, and (later) a 5th biome. Doubles stay for
  variety; animal needs add on top.
- **Clockwise blooms are a later-valley challenge.** With
  `"bloom_order": "clockwise"` a bloom needs its three biomes in the order
  listed in its recipe, going clockwise round the corner (any starting
  point); the reverse makes nothing, which makes Mirror a real choice. The
  first valley uses `"any"` (any three different biomes bloom) so it's easy
  to learn; later valleys switch the rule on as a step up.
- **Readable blooms** (Dorfromantik's matching is easy to read because each
  check is local and binary; these bring that to corners):
  - *Bloom spots are marked:* blooms only grow where three different pieces
    meet, which players couldn't see (playtest: a forest + meadow + wetland
    corner "didn't bloom" because two of its hexes were one piece). Every
    such corner that can still bloom shows a small gold stitched star.
  - *Buds on open corners:* every corner with two of its three hexes filled
    shows a bud on a stem, with one coloured knot per biome that would make
    it bloom. Reading a corner becomes colour matching. Corners that can no
    longer bloom show no bud.
  - *Blooms show their recipe:* each bloom has two petals pointing at each of
    its three hexes, in that hex's biome colour (with a dark outline stitch),
    and a centre in the bloom's own colour. Blooms and buds stand on short
    stems above the puffy patches.
  - *Recipe guide matches the rule:* with the order rule on, the Blooms panel
    draws each recipe as three coloured wedges meeting at a point with a
    clockwise arrow. With it off ("any order"), recipes are drawn as three
    biome swatches joined by "+", because a ring suggests an order that
    doesn't matter (playtest: a bloom looked "reversed" next to the ring).
  - *Combo points:* blooms made by the same placement are worth more each:
    2, 3, 4, 5, 6, 7 points (2 blooms = 5, 3 = 9, 6 = 27). Settings
    `bloom` and `combo_step` in each valley's scoring. The Place button shows
    the points a placement would earn. Rewards leaving gaps on purpose so a
    later piece completes several corners at once. (Greedy test player: 2
    blooms in one placement about once per valley, never 3+.)
  - *Perfect piece:* all six bloom spots around a piece bloom, which is only
    possible when it fills a gap with every neighbouring plot placed. A rare
    jackpot: +5 seeds (`perfect_seeds`), a big petal burst and a message, on
    top of the 27 combo points.
- **Bloom preview stays:** the ghost piece shows flowers where corners would
  bloom.
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
- **Valley rules (both modes).** Each valley has a fixed outline made of
  plots, and you get exactly enough pieces to fill it. The run ends when the
  valley is fully restored; every run in a valley has the same length, and
  the score measures quality (blooms, corridors, discoveries), not how long
  you lasted. Blooms earn *choice*, not extra pieces.
- **Two game modes:**
  - **Progression:** a series of levels, each a hand-made valley with a
    predefined shape (plus its biome mix, rules, animals and landmark).
    Levels unlock through discoveries.
  - **Custom:** valleys with generated shapes and sizes. The player picks
    4–5 biomes from those already discovered in Progression (or lets the
    game pick at random), so Progression stays the way to find new biomes.
    New blooms and animals found in Custom go into the journal, but only
    Progression levels unlock new levels and biomes.
  - These replace the earlier "open mode" idea (map grows until the pile
    runs out), which would have brought Dorfromantik's economy loop back.
- **Many different valley shapes.** Outlines vary widely between valleys,
  not just the round first valley.
  - *Custom shapes are carved by terrain:* the generator makes hills and
    ridges, and the valley is the low ground between them, so the outline
    always matches the landscape around it (passes, side basins; cliffs
    become obstacles). Rejected for now: river-carved, quilt-block patterns,
    player-painted outlines, and a plain random blob (too boring).
  - *Custom sizes:* presets S / M / L / XL, about 20 / 35 / 50 / 75 plots
    (roughly 6 / 12 / 18 / 30 minutes).
  - *Progression levels can be big too*, and there may be a very large
    number of them. They're made by **generate, curate, fix**: the
    generator makes many candidates offline, the balance sim plays them,
    the good ones are kept and saved as fixed level files; key levels are
    hand-made.
- **Obstacles as fixed features.** Some valleys have obstacle hexes inside
  the outline (lake, cliff, ruins) that pieces can't fill. Blooms can't use
  them, but they shape the board and can count for animals (e.g. otters
  like a lake shore).
  - *First obstacle kinds:* **lake** (otters, herons, frogs want corridors
    along its shore), **cliff / crag** (eagles and goats; splits the
    valley), **ruins** (an old wall or chapel; owls and bats) and **ancient
    wood** (a grove too old to change; badgers and owls).
- **Seeds are the bloom currency.** Each bloom gives 1 seed. You always see
  the current piece and the next one. Spend seeds to: set the current piece
  aside in a single reserve slot; swap the current piece with the next one;
  or see the next 3 pieces for one turn. Leftover seeds count a little
  toward the final score. Valley size is fixed, so seeds improve the valley
  without making runs longer. **Costs (starting values, tune in playtests):**
  set aside 1, swap 1, look ahead 2.
- **Progression through discoveries, not score.** New blooms go into the
  journal the first time a trio is made; animals settled by corridors are
  recorded too. Discoveries unlock new valleys, biomes and valley variants
  (e.g. settling otters opens a river valley; finding every bloom in a valley
  reveals a hidden variant). Score stays as a personal best per valley.
- **Progression map: branching, by region.** A quilted world map split into
  regions (e.g. Lowlands, Moors, River Country) of about 8–15 levels each.
  Several levels are open at once, so the player is never stuck.
- **Star goals open levels; stars come from discoveries, never score.** Each
  level has 3 stars: restore the valley, settle all residents, find the
  hidden visitor. Finishing any level always opens its neighbour on the map,
  so nobody gets stuck; stars are needed only for region gates (about half
  a region's stars, e.g. 15 of ~30) and bonus levels. Discoveries also fill
  the journal and open new biomes.
- **Difficulty rises through** bloom rules (clockwise order, a 5th biome,
  fewer recipes), awkward shapes and obstacles (narrow passes, islands of
  plots, cliffs and lakes that break up corners) and harder animal asks
  (longer corridors, specific blooms, loops, migration routes). The seed
  economy stays the same.
- **One reserve slot** (Set aside), always; variety comes from the valleys.
- **Influence is visual only (for now).** Where two pieces meet at a seam,
  good biome pairs show small signs of life (taller trees by wetland,
  heather creeping into meadow beside heath). No effect on rules or score.
  Pairs are defined in a data table so they can gain rules later. Good
  pairs are **natural neighbours** (wetland + forest, heath + meadow);
  pairs that don't meet in nature (e.g. heath + wetland) stay plain.
  - *Recorded for later:* influence as a full mechanic, where pairs change
    hexes (e.g. forest next to wetland becomes "lush forest", which can make
    special blooms). Revisit if playtests show the game lacks depth.
- **Run length grows with progress.** First valleys are small (~20 plots,
  ~5–8 min). Later valleys grow to 30–45 plots (~10–20 min). Larger games
  are also wanted: big valleys (60+ plots), in both modes. Every valley can be paused and resumed at any time.
- **Animals: residents plus a hidden visitor.** Each valley shows its 2–4
  resident animals and their needs before the first piece (e.g. "Otters: a
  5-bloom corridor touching wetland"). One hidden visitor also settles if a
  secret pattern gets built, which feeds the journal and replays. All animal
  goals are optional; missing one only means that animal doesn't move in
  this time. (Rejected: pop-up requests during a run, too close to
  Dorfromantik's quests.)
  - *What animals can ask for:* corridor length and biomes touched, plus
    specific blooms (e.g. bees want a corridor through 2 Foxglove Glades),
    obstacles nearby (otters want the lake shore, eagles a cliff) and the
    corridor's shape (a loop for hedgehogs, or a route linking two far ends
    of the valley for migrating animals).
  - *Seeds scale with difficulty:* easy residents give 2, hard ones 3–4,
    the hidden visitor 5. Set per animal in data.
  - *The hidden visitor is hinted by a riddle* on the valley's journal page
    (e.g. "something stirs where three heaths meet the water"); the full
    answer is shown once it's found.
- **Placement and start.** Each piece must touch a piece already placed, so
  the valley grows outward like restoration spreading. Every valley starts
  from a fixed **landmark piece** in its centre: three different biomes from
  that valley, with a landmark at its confluence (an old tree, a spring). It
  follows the normal rules but is the valley's heart. **One landmark per
  region** (e.g. Old Oak, Spring, Standing Stone, Mill), with small
  variations between its levels, gives each region its identity.
- **Same-biome trios may bloom, selectively.** Some trios with repeated
  biomes get a recipe (e.g. three forests = "deep wood", two wetlands + a
  meadow = "reed bed"); not every trio does. Each valley lists its recipes,
  keeping it readable at about 4–6. The first valley only has all-different
  recipes so far.
  - *Recipe list per valley:* its all-different trios plus one or two
    same-biome recipes, which are the special, harder-to-plan extras.
  - *Same points as other blooms*, but a special look, and they stand out
    in the journal.
  - *Custom mode recipes come from the journal:* the all-different trios of
    the chosen biomes plus the same-biome recipes already discovered for
    them.
- **Scoring: points.** Blooms (2 each, rising in combos), a bonus per
  settled animal that scales with its difficulty (about 8 for an easy
  resident, 12–15 for a hard one, 20 for the hidden visitor; set per animal
  in data), and 1 point per 3 leftover seeds as a small tiebreaker. Best
  score kept per valley.
- **Prototype animals: otters and deer.** Otters want a corridor of 4+ blooms
  that includes wetland; deer want a long corridor (6+ blooms) passing
  through forest.
- **First-valley blooms (natural place names):**

  | Trio | Bloom |
  |---|---|
  | forest + meadow + wetland | Fern Hollow |
  | forest + meadow + heath | Foxglove Glade |
  | forest + wetland + heath | Misty Carr |
  | meadow + wetland + heath | Cotton-grass Moor |
- **Settling an animal gives seeds** right away (plus its points), so it helps
  the rest of the run.
- **Trails are visual only in the prototype.** The edge-habitat idea stays
  recorded for later.
- **Atmosphere.**
  - *Visual style: textile / embroidery.* Pieces are fabric patches (forest =
    soft felt, meadow = linen, wetland = shimmering silk, heath = purple tweed);
    piece borders are stitched seams; corridors are embroidered thread along
    those seams; blooms are embroidered flowers; animals are small woven
    figures. The valley reads as a quilt coming to life.
  - *Textile details (first pass, built):* quilted, puffy patches (each hex
    domed like a stuffed square); dashed running stitches in dark thread
    along piece borders; corridors as a bright, raised embroidered thread
    along those seams; blooms as embroidered flowers (satin-stitch petals and
    leaves, French-knot centre). Fabrics per biome live in data/biomes.json:
    forest felt, meadow linen, wetland silk, heath purple tweed. Each empty
    plot is one trefoil-shaped piece of backing cloth (with a small gap
    between plots) and a stitched outline, so you can see where every piece
    can go; plots you can place on right now are lighter, with an orange
    outline.
  - *Biome details:* forest has felt pines and round trees with shrubs;
    meadow has stitched grass tufts and daisy-stitch wildflowers in several
    colours; wetland has thread reeds with cattails, felt lily pads and
    wavy running-stitch ripples; heath has French-knot heather in mixed
    purples and gorse.
  - *No two tiles alike:* each tile gets its own layout, counts and sizes
    (seeded by its hex, so the placement preview matches the placed tile),
    a slightly different fabric shade, and sometimes a rare extra:
    mushroom or fallen log (forest), rabbit or stone (meadow), frog on a
    lily pad or duck (wetland), boulder or birch (heath).
  - *Surroundings (built):* the valley sits in a landscape so it reads as a
    place, not a board. Around the plots lies faded land: grey, washed-out
    cloth with dry tufts that regains colour next to restored hexes. Beyond
    it a ring of quilted hills (puffy domes with running-stitch contours)
    carries felt woods, sheep and three red-roofed cottages, and a silk
    stream runs down from the hills into a pool at the valley's edge.
    Further out, layered distant hills and slow felt clouds under a soft sky.
  - *Living surroundings:* the whole landscape (ground, hills, woods, sheep,
    cottages, stream, distant hills) starts washed-out grey and regains
    colour in step with how much of the valley is restored; an animal that moves in also appears on the
    hills; a finished valley gets birds circling and chimney smoke.
  - *Camera:* tilted 3D view with free orbit and zoom.
  - *Placing by touch:* tap a plot to preview the piece there, tap it again
    to turn it (instantly), press and hold (0.45 s) to place it as shown.
    Double-tap to place was tried and dropped: telling it apart from a turn
    made turning feel slow.
  - *Sound:* **folk acoustic** music (soft guitar, harp, fiddle, recorder),
    one tune per region; each biome adds nature sounds (birdsong, water,
    wind in heather) that layer up as the valley fills; fabric rustle on
    placement.
  - *Feedback:* blooms and settling animals use short, gentle animations that
    never interrupt; the player can keep placing straight away.
- **Tech: Godot 4 + GDScript** (switched from three.js; iPhone and Android
  are long-term targets). Use the latest stable 4.x at start.
  - **Prototype is a web build published to GitHub Pages.** Use the
    Compatibility renderer (the only one Godot supports on the web, and it
    also runs on mobile), and export with thread support off, since GitHub
    Pages can't send the headers that threaded web builds need.
  - Hex math, rules/scoring and rendering in separate parts; rules are plain
    GDScript classes with no scene or engine-node dependencies, tested
    headless with **gdUnit4**.
  - Biomes, bloom trios, influence pairs, valleys and pile composition are
    data (JSON).
  - Axial coordinates; any vertex returns its three surrounding hexes.
  - Not C#: Godot's C# export to iOS/Android is still marked experimental,
    and C# can't export to the web.
  - **Phone performance budget:** settled pieces, blooms and scenery are
    merged into a few meshes, with colour stored in the vertices so tinted
    cloth shares one material (one draw call per material, not per colour).
    The board merges in chunks of 6 pieces, so a placement only rebuilds its
    chunk (a few ms). 3D renders at no more than 2 device pixels per CSS
    pixel (≈67 % on 3× iPhones; the interface stays sharp), and phones use a
    2048 shadow map. With 13 pieces placed: ~250 draw calls, down from ~1750.
    `tools/perf_probe.gd` breaks the draw calls down by part.

## Open questions

### Geometry and placement
- Terrain generator details: what keeps a carved valley fair (connected,
  no one-plot inlets, enough weave points) and how obstacles are placed.
- Exactly how "near an obstacle" is measured for animals.
- Which landmark each region has.

### Biomes and valleys
- Which same-biome recipes exist (names, looks).

### Wildlife corridors
- Later twist (recorded, not chosen for now): animals prefer trails that run
  between *different* biomes (edge habitat), so the biomes on either side of
  a trail would matter too.

### Scoring and economy
- Fine-tuning the point values in playtests.

### Biome interactions
- What each good pair looks like.

### Requests / goals
- The animal roster: which animals exist and their exact asks.
- Riddle wording, and how hard each visitor's pattern is.

### Difficulty and run length
- How fast each difficulty lever ramps across regions.

### Progression and unlocks
- Which discoveries open which bonus levels and biomes.

### Atmosphere
- Exact biome sound layers and how they mix.

## Dorfromantik comparison

| Area | Dorfromantik | Bloomweave (current draft) | Risk |
|---|---|---|---|
| Tile | Single hex, 6 edge segments | Trefoil of 3 whole-hex biomes | Distinct |
| Matching | Edges match edges | Trios meet at vertices | Distinct |
| Run end | Stack runs out | The valley is full (both modes) | Distinct |
| Extending the run | Perfect placements and quests add tiles | Blooms earn choice, not pieces | Distinct |
| Meta | Score unlocks tiles and biomes | Discoveries (blooms, animals) unlock valleys and biomes | Distinct |
| Terrain set | One fixed set of terrain types in every run | Different biome mix per valley | Distinct |
| Board | Freeform single hexes | Fixed grid of trefoil plots | Distinct |
| Mood | Cozy, pastoral | Cozy, restoration | Close (genre-typical) |
| Look | Soft low-poly 3D, model-railway feel | Textile / embroidered quilt | Distinct |

Pieces, matching, board and terrain sets are clearly different. Fixed
valleys replace Dorfromantik's economy loop (finite stack, earn more tiles by
placing well); the dropped open mode would have brought it back. Progression through discoveries replaces score-based unlocks.

## Prototype scope (built)

- One valley: about 20 plots in a round-ish outline around the landmark,
  first-valley biomes (forest, meadow, wetland, heath).
- Piece list from JSON: mostly three-different pieces plus some doubles.
- Place, rotate and mirror with a preview of which corners would bloom.
- The 4 named blooms (data-driven); seeds with set aside, swap, look ahead.
- Corridors drawn along piece borders; 2 resident animals: otters and deer.
- Simple end screen with the score.
- Simple coloured 3D hexes with orbit camera (textile look later).
- Godot web export, deployed to GitHub Pages.
- Rules in their own module with unit tests: hex math, plot lookup, corner
  lookup, bloom checks, corridor finding.
- Later: journal and unlocks, hidden visitor, sound, textile shaders,
  influence visuals, Custom mode and more Progression levels.

### Prototype notes

- **Corridor size** counts every bloom in a linked group, so branches count
  too. Each link is drawn as a trail along piece borders.
- **Animal needs (first valley):** otters want 5+ linked blooms with 4+
  touching wetland; deer want 8+ with 6+ touching forest. Settling gives
  points (10 / 15) and 2 seeds.
- **Scoring:** 2 per bloom, animal points, 1 per 3 leftover seeds.
- **Seed actions:** "Use set-aside" (free) brings the reserved piece back as
  the current piece; the current one becomes next. If the pile runs out, the
  reserved piece is played automatically.
- **Balance check, first valley without the order rule** (200 runs, greedy
  player): about 16 of 24 corners bloom, otters settle in about 91% of runs,
  deer in about 73%. Easy, as intended for the first valley.
- **Balance check with clockwise blooms** (200 runs, greedy player that
  maximises blooms each turn, never spends seeds): about 12.5 of 24 possible
  corners bloom (was 16 without the order rule); a bloom is possible on about
  65% of turns (was 83%); otters settle in about 70% of runs, deer in about
  44%; about 15 seeds are left over.
- **Options compared for "blooms are too easy"** (bloom possible / blooms):
  as before 83% / 16; more doubles 84% / 16; only 2 of 4 trios 68% / 13;
  clockwise order 65% / 12; 5th biome in no trio 55% / 10; 5th biome in
  some trios 80–84% / 15–16.
- **Valley size:** 19 plots (plot radius 2): the landmark plus 18 pieces
  (14 with three different biomes, 4 doubles).
