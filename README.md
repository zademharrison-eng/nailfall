# Nailfall

A platform fighter that mixes Hollow Knight style nail combat with Brawlhalla style damage-percent knockouts. Two masked knights duel in a ruined cavern: hits raise your rival's damage, higher damage sends them flying farther, and three knockouts win. All code and art are original.

## Play

- **In the browser:** https://zademharrison-eng.github.io/nailfall/ (the `web/` folder, published automatically on every push to `main`).
- **In Godot:** open Godot 4.3 or newer, choose **Import**, pick `godot/project.godot`, then press **F5**. Keyboard and controllers both work.

## Controls

| | Pale Wisp (player 1) | Ember Husk (player 2) | Controller |
|---|---|---|---|
| Move | A / D | Left / Right | Stick or d-pad |
| Jump (twice for wings) | W | Up | A |
| Nail (aim with up/down) | F | `.` or Num 1 | X |
| Dash | G | `/` or Num 2 | B or RB |
| Spell, or down + spell on the ground to heal | H | `,` or Num 3 | Y |

Esc or Start pauses, M mutes. Against the CPU, player 1 can also use the arrow keys with J, K and L.

## Layout

- `web/index.html` is the browser version, one self-contained file.
- `godot/` is the Godot 4 project. `main.gd` holds the whole game and draws everything in code.
- `godot/fonts/` holds IM Fell English SC, licensed under the SIL Open Font License (`OFL.txt`).
