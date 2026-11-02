# Concept art prompts (Varco, round 1)

Common suffix for every prompt:

> highly detailed pixel art, 32-bit era, crisp hard-edged pixels, no anti-aliasing, limited cohesive palette, no readable text, no logos, no UI, no watermark

Four style directions, each rendered as a top-down gameplay mockup (16:9) and a key art scene (3:4).

| ID | Direction | Palette / mood |
|---|---|---|
| S1 | 야간 가스등 | warm amber gaslight, brick, glowing signage, night |
| S2 | 녹청 산업 | teal-green fog, oxidized copper, brass pipes, giant gears |
| S3 | 녹슨 황혼 | rust orange dusk, desaturated ruins, smoke haze |
| S4 | 차가운 감시 | cold blue-grey, searchlights, red propaganda lamps |

Feedback: S1 reads best for gameplay but feels too cozy; it is a ruin. Mix in S3's decay while keeping interiors intact enough for indoor fights.

# Round 2 (top-down gameplay only, 2 each)

| ID | Direction | Notes |
|---|---|---|
| R1 | 달빛 + 깨진 가로등 | cold moonlight base, a few flickering amber lamps, caved-in roofs, bloodstains |
| R2 | 황혼 폐허 | S3 rust/ash dusk with S1's hard light/shadow contrast, interiors usable |
| R3 | 모닥불만 남은 밤 | no street lights; campfires, burning barrels and lanterns on blue-black |

Decision: R1 moonlight as the base tone, R3 fires marking enemy camps.

# Sprite test (Toa)

| ID | Approach | Result |
|---|---|---|
| A | overhead, 4 poses | came out as a side/3-4 hybrid with legs; does not rotate cleanly |
| B | 3/4 view, 8 directions | very consistent, but the rifle is baked in and walk cycles would need 8 x N frames to stay consistent |
| C | true overhead single sprite + weapon row | true overhead body that rotates like the current rig; weapons usable as pickups and bag icons |

All three are on a magenta (#FF00FF) background for keying. The "pixels" are not on an exact grid, so imports need keying plus a nearest-neighbour downscale to the target art size.

Feedback: C is not real pixel art; A's style is right but the camera must be fully overhead.

# Sprite round 2 (A style, true overhead)

- D_overhead_gen_a / gen_b: generated with A as style reference. Both give four consistent overhead poses (unarmed, rifle, pistol, bat). **gen_b chosen.**
- D_overhead_edit: edit of A; perspective fixed but poses repeated, rejected.
- E_scav / E_pmc / E_centra: enemies generated with gen_b as reference, same layout.

Sheets are imported with `game/tools/import_sprites.gd` (magenta key, majority-vote downsample to an 18px shoulder height, speck removal, pivot centred) into `game/assets/sprites/<name>_<pose>.png`.

# Sprite round 3 (symmetric overhead Toa)

Feedback: the camera was not perfectly overhead; shoulders looked lopsided. Regenerated Toa with an exact orthographic, left-right symmetric prompt (gen_b as style reference). **F_sym_a chosen** and imported as toa_*. Enemies still use round 2 sheets.
