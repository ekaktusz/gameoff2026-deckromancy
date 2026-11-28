# Deckromancy

## Play the prototype

Open the project in Godot and press **F5**, then choose **Start**. Drag three of
the four random starting cards into slots under **Your army**, then click a
location to enter its fight. The chosen slots set the opening formation.
The city's thirteen stages end with Darius, beyond the Citadel Lord. Before each
fight, drag cards to rearrange them.
Between rounds and after the last enemy falls, drag a graveyard card into an
empty ally slot to raise it. Fallen allies and enemies both go to the graveyard.
To sacrifice an ally, select it between rounds and press **Sacrifice**. It gains
a MARK as it enters the graveyard. Open `game_loop.tscn` and press **F6** to start
at the graveyard while iterating.

## Where to work

| Area | Files |
| --- | --- |
| Screen flow and encounter order | `game_loop.gd`, `game_loop.tscn` |
| Combat, resurrection, and run state | `Gameplay/` |
| Unit names, starting stats, abilities and portraits | `Gameplay/Units/*.tres` |
| Card look and card animations | `Scenes/Card/card_2d.tscn`, `card_2d.gd` |
| Battle board, slot layout and round playback | `Scenes/BattleGround/` |
| Graveyard grid (start of run and in battle) | `Scenes/Graveyard/` |
| City map | `Scenes/Map/` |
| Card artwork, unit portraits, city backgrounds, UI font and music | `assets/cards/`, `assets/units/`, `assets/backgrounds/`, `assets/fonts/`, `assets/music/` |
| Sound effects (generated: hit, empty hit, shift, hover, select, RiP gain/loss) | `assets/sfx/`, regenerate with `python3 tools/generate_hit_sfx.py` |

Edit **Enemy Pool** and **Encounters** on the GameLoop node in the inspector.
The pool also supplies the random starting cards. Each encounter supports up to
five enemies. Set **Random Enemy Count** to draw that many units from the pool.
The map previews their types and
counts, and the fight uses the same draw. Set the count to zero to use the fixed
**Enemies** list. Use **Map Stage**, **Map Lane**
and **Next Lanes** to place and connect encounters.
**Portrait Gradient** colors enemies when they spawn. Recruited units carry
their palette into later fights. The battle background pans toward the keep as
the route progresses.

The graveyard and battle screens are Node2D scenes. Each unit's **Art** group
sets its `portrait` and `portrait_tint`. A same-size `mark_overlay` is drawn over
the portrait once the unit carries a MARK. Cards without a layer can use a
`marked_portrait`. Slot positions are
the `Slot0`–`Slot4` markers under `EnemySlots` and `AllySlots` in
`battle_ground.tscn`. `ANIM_SPEED` in `battle_view.gd` scales every battle
animation. The battle screen plays shifts, faction abilities and attacks in
order. Damage applies on impact.

Resurrection Points are called RiP in game. The prototype uses 3 starting RiP,
holds at most 5, and awards 1 RiP whenever an unmarked enemy dies. Attacks on
empty slots leave RiP unchanged.
Defenders always retaliate, even when the attack kills them.
Revival percentages use the unit's base stats and current MARKs, rounded to the
nearest whole number with a minimum of 1. At four MARKs, a card becomes a
stationary 1/1 Poop Warrior with no active abilities. A player with an empty army
can still raise a creature before choosing to end the run. HP and unspent RiP
carry into the next encounter. Each battle starts with a fresh graveyard.

Birds try to shift one slot left at the start of each round, starting from the
player's chosen formation. They can enter a vacant slot or swap with a bug or
movable mammal. Each card can move once per round. Bone Ward keeps its slot.
Doomed Jackdaw can jump over one stationary ally into a vacant slot. It dies
when it cannot shift or land. If no column has units on both sides after shifting,
the closest opposing pair trades blows across lanes.

Cards show their faction and ability. Blocked shift deaths resolve before stat
bonuses, and stat changes appear above the affected cards.
Only player-controlled cards can gain stats from the graveyard. The bonus expires
at the start of each round and is reapplied in full using the current graveyard size.
Bonus HP absorbs damage first. Temporary ATK and remaining bonus HP expire at
the end of the encounter.

## Web export and itch.io deployment

Use **Godot 4.7.2 stable** with its matching export templates. The project uses
Compatibility rendering and the `Web` preset is single-threaded.

One-time setup:

1. In [itch.io project 5414022](https://itch.io/game/edit/5414022), set **Kind of
   project** to **HTML**. Leave **SharedArrayBuffer support** off for this build.
   Keep the page’s visibility set to what you want for the jam.
2. Create an [itch.io API key](https://itch.io/user/settings/api-keys) under an
   account that can upload to the project. Store it directly in [GitHub Actions
   secrets](https://github.com/ekaktusz/gameoff2026-deckromancy/settings/secrets/actions/new)
   as `BUTLER_API_KEY`. Never commit or share the key.
3. Merge the workflow to `main`. Check **Actions → Web export and itch.io deploy**.
   On itch.io, confirm the `html5` upload is marked to play in the browser, then
   launch it from the game page. You may need to set this checkbox after the first
   upload. Subsequent deploys update the same channel without changing visibility.

Pull requests build a downloadable `deckromancy-web` artifact but never deploy.
Pushes to `main` build and publish to the `html5` channel. To retry, use **Run
workflow** on `main`. The workflow resolves project ID `5414022` to its itch.io
owner and slug; it never deploys to the old sandbox target.

To test locally after installing the matching export templates:

```sh
mkdir -p build/web
godot --headless --editor --import
godot --headless --export-release Web build/web/index.html
python3 -m http.server --directory build/web 8000
```

Open <http://localhost:8000/>. Don’t open `index.html` directly from disk.

## TODO

- [ ] Copy a more recent intro variant with debug skip

## Local VS Code tasks

Make sure `godot`, `gdformat`, and `gdlint` are on your PATH.
