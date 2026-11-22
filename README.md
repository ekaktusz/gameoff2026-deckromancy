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
| Unit names and starting stats | `Gameplay/Units/*.tres` |
| Editable screen layouts and card UI | `Scenes/` |

Edit **Starting Units** and **Encounters** on the GameLoop node in the inspector
to change the prototype content. Each encounter supports up to five enemies.

Resurrection Points are called RiP in game. The prototype uses 3 starting RiP,
holds at most 5 (extra gains are lost), and awards 1 RiP for an unmarked enemy
kill. An ally attacking an empty enemy slot gains 1 RiP, but each slot pays
out only once per battle; an enemy attacking an empty ally slot costs 1 RiP
every time (never below 0).
Defenders always retaliate, even when the attack kills them. Raised units take the first vacant slot.
Revival percentages use the unit's base stats, rounded to the nearest whole
number with a minimum of 1. When the formations have no opposing pair, the
first ally moves into the first enemy's column before attacks resolve. A player
with an empty army can still raise a creature before choosing to end the run.
HP and unspent RiP carry into the next encounter. Each battle starts with a
fresh graveyard. These rules are provisional while the team settles combat
and shift behavior.

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
