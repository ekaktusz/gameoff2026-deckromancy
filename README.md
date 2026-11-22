# Deckromancy

## Play the prototype

Open the project in Godot and press **F5**, then choose **Start**. Raise at least
one creature, enter the city, and fight through six encounters: the lower
streets, the gatekeeper, the inner city streets, the inner gatekeeper, the
citadel streets, and the citadel lord. Before each fight, click two slots in
your row to swap them. Use the graveyard between rounds and after the last
enemy falls. Open `game_loop.tscn` and press **F6** to start at the graveyard
while iterating.

## Where to work

| Area | Files |
| --- | --- |
| Screen flow and encounter order | `game_loop.gd`, `game_loop.tscn` |
| Combat, resurrection, and run state | `Gameplay/` |
| Unit names, starting stats, shift and portraits | `Gameplay/Units/*.tres` |
| Card look and card animations | `Scenes/Card/card_2d.tscn`, `card_2d.gd` |
| Battle board, slot layout and round playback | `Scenes/BattleGround/` |
| Graveyard grid (start of run and in battle) | `Scenes/Graveyard/` |
| City map | `Scenes/Map/` |

Edit **Starting Units** and **Encounters** on the GameLoop node in the inspector
to change the prototype content. Each encounter supports up to five enemies.

The graveyard and battle screens are Node2D scenes. Each unit's **Art** group
sets its `portrait`, an optional `marked_portrait` shown once it carries a MARK
(otherwise the portrait is tinted), and a `portrait_tint`. Slot positions are
the `Slot0`–`Slot4` markers under `EnemySlots` and `AllySlots` in
`battle_ground.tscn`. `ANIM_SPEED` in `battle_view.gd` scales every battle
animation. The battle logic returns a list of `BattleEvent`s per round, which the
battle screen plays back in order.

Resurrection Points are called RiP in game. The prototype uses 3 starting RiP,
holds at most 5 (extra gains are lost), and awards 1 RiP for an unmarked enemy
kill. An ally attacking an empty enemy slot gains 1 RiP, but each slot pays
out only once per battle; an enemy attacking an empty ally slot costs 1 RiP
every time (never below 0).
Defenders always retaliate, even when the attack kills them. Raised units take the first vacant slot.
Revival percentages use the unit's base stats, rounded to the nearest whole
number with a minimum of 1. A player with an empty army can still raise a
creature before choosing to end the run. HP and unspent RiP carry into the next
encounter. Each battle starts with a fresh graveyard.

Every unit has a **Shift** pattern, set per unit in `Gameplay/Units/*.tres`:
Hold, Left, Right, or Bounce. From round 2 on, both rows shift one slot before
attacks; round 1 fights in the order the player arranged. A unit only moves
into an empty slot in its own row, otherwise it stays put. Two neighbours
heading toward each other (for example a Right unit next to a Left unit, or two
Bounce units facing each other) swap places instead. Left movers resolve
from the left and right movers from the right, so a line heading the same way
moves together. Left and Right units stop at the edge; Bounce units start
heading right and turn around at the edge. If no column has units on both
sides after shifting, the first ally moves into the first enemy's column so
the fight cannot stall. These rules are provisional while the team tunes them.

## TODO

- [ ] Update Godot version to 4.6
- [ ] Copy a more recent intro variant with debug skip

## Tools

To set up auto-deploy to itch:

- [ ] In /.github/workflows/deploy.yml set and check the following settings:
    - GODOT_VERSION
    - EXPORT_NAME
    - ITCH_USERNAME
    - ITCH_GAME_ID

- [ ] set the BUTLER_API_KEY
    - generate a key at: https://itch.io/user/settings/api-keys
    - store the repository secret on github

Itch project settings

- [ ] SharedArrayBuffer support" should be checked

Local VSCode tasks

- [ ] make sure that _godot_ is on the path
- [ ] make sure that _gdtools_ is installed and _gdformat_ and gdlint are on the path
