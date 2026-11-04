# Lato

A small Ori-inspired 2D platformer made in **Godot 4.4+**. It uses the Kenney
*Abstract Platformer* art for now, and you can swap in your own later.

The hero is the little grey one-eyed creature, followed by a glowing spirit
companion through a dark purple forest lit by orbs, lanterns and shrines.

## Running it

1. Install [Godot 4.4](https://godotengine.org/download) or newer (the standard build, not .NET).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press **F5** (Run Project).

The first open takes a few seconds while Godot imports the art.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Move | A / D or arrow keys | Left stick / D-pad |
| Jump (hold for higher) | Space, Z or K | A |
| Dash *(unlockable)* | Shift, X or L | X, RB or RT |
| Bash *(unlockable)*: hold to aim, release to launch | C, J or E | Y, B or LT |
| Map | M or Tab | Select / Back |
| Pause | Esc or P | Start |
| Restart from the beginning (wipes the save) | R | Back |
| Fullscreen | F11 | |

## What's in it

**Movement feel (priority #1).** All of these are in `scripts/player.gd`:

- Acceleration curves, with a faster turn-around when you reverse direction.
- Variable jump height (let go early for a short hop).
- Coyote time (you can still jump just after running off a ledge).
- Jump buffering (a jump pressed just before landing still counts).
- Apex hang: gravity eases off at the top of a jump while jump is held.
- Heavier fall gravity and a fast-fall when holding Down.
- Corner correction, so near-miss jumps slip around ledges.
- Wall slide and wall jump. Hold toward the wall to climb a single wall, as in Ori.
- Squash and stretch, a running lean, flips, landing dust and screen shake.
- A light trail at speed and a camera that looks ahead in the direction you're moving.

**Discovery.**

- 45 spirit orbs that drift toward you when you get close.
- A key and a locked door.
- Cracked walls that you dash through.
- Secret areas behind fake walls, which fade when you walk in. Look for a faint glow leaking through the rock.
- Checkpoint flags, signs with hints, and a goal at the end.

**Skills**, each unlocked at a glowing shrine:

1. **Double Jump**: press jump again in mid-air.
2. **Spirit Dash**: a fast horizontal burst that breaks cracked stone. Dash-jumping keeps your momentum.
3. **Bash**: near a lantern or an enemy, hold Bash. Time slows down while you aim; release to launch. The object gets knocked the other way.
4. **Glide**: press jump in mid-air and keep holding it. Rising winds (updrafts) lift you.

## Swimming

There's a hidden lake under the opening meadow: drop through the gap between the
first two steps. Underwater you swim freely with the move keys or stick. You float
gently upward, **Jump** kicks you forward in the direction you're holding, and Jump
at the surface leaps out. Dash and Bash still work underwater. Diving in splashes,
and while you're under the screen tints blue and the sound goes muffled.

Add water anywhere with `~` in the level file. Orbs and enemies placed in water count as water too.
Swim tuning is in the **Swim** group on the Player.

## Bells and whistles

- **Sound:** every sound effect and the ambient music is generated in code at startup
  (`scripts/sfx.gd`, autoload `Sfx`), so there are no audio files. Orb chimes climb a
  scale when you grab them in a row. Glide wind and wall-slide scrape are loops that fade
  in and out. Reverb is on the `SFX` and `Music` buses.
  To use real recordings later, put them in `Sfx.sounds["jump"] = load("res://audio/jump.ogg")`, and so on.
- **Saving:** touching a checkpoint or a shrine saves your progress: skills, orbs,
  opened doors, broken walls and secrets found. Quit and relaunch to continue. On the
  title screen, **N** starts a new game, and **R** in-game also wipes the save and restarts.
- **Title screen**, **pause menu** (Esc / Start, showing orbs, time, falls and skills),
  and a finish screen with your time.
- **Living world:** plants sway in the wind and get pushed aside when you run
  through them or land near them. Dark foreground silhouettes frame the screen edges.
- **Whooshes:** dashing, bashing, double-jumping, gliding low and hard landings push a wave
  of air that flings nearby plants and vines aside, and brushed plants release glowing spores.
- **Swinging vines** with glowing tips hang under ledges and platforms. They're simulated
  as ropes, so they swing when you run, dash or glide through them. Leaves drift down through the air.
- **Map** (M / Tab / Select): areas reveal as you explore them (saved with your game).
  It shows terrain, checkpoints, unclaimed shrines, doors, orbs you've spotted but not
  collected, the goal, and you. Jump or Dash zooms in, and move pans.
- Wall-slide sparks, footstep dust, and gamepad rumble on impacts.

## Tuning the feel

Every movement value is exported. Open `scenes/player.tscn` and select the
`Player` node. The Inspector groups the settings into Run / Jump / Wall / Dash / Glide / Bash.
For live tweaking, run the game from the editor, then in the **Remote** scene
tree select `Main/World/Player` and change values while you play.

Some useful ones:

- `max_speed`, `ground_accel`, `air_accel`: how snappy running feels.
- `jump_height`, `jump_time_to_apex`, `fall_gravity_mult`: the shape of the jump arc.
- `apex_gravity_mult`: how much the jump "hangs" at the top.
- `coyote_time`, `jump_buffer_time`: how forgiving the timing is.
- `wall_climb_velocity`: how fast you climb by wall-jumping on one wall.

The camera has its own settings in `scripts/game_camera.gd`. The darkness of the world is
`ambient` on the `Main` node (`scripts/main.gd`).

## Editing the level

The level is the plain text file `levels/level1.txt`, where **one character is one 64px tile**.
Edit it in any text editor and run again. Ground tiles pick their own edge pieces automatically.

```
#  ground                 =  one-way platform        ^  spikes
P  player start           o  spirit orb              k  key
D  locked door (2 tall)   B  breakable (dash) block  L  bash lantern
E  floating enemy         C  checkpoint              S  sign
1  double jump shrine     2  dash shrine             3  bash shrine
4  glide shrine           s  secret (fake) wall      W  updraft
G  goal                   ~  water
```

Sign texts go after the `---` line, one per line, in left-to-right order of the
`S` signs in the map.

Rough reach distances, for designing gaps:

- Single jump: about 3 tiles high and 5.5 tiles across.
- Double jump: about 8.5 tiles across.
- Double jump plus dash: 10–12 tiles across.

## Swapping in your own art

- **Player:** `skin` on the Player node switches between the Kenney Grey, Blue, Green and Red characters.
  For your own character, keep the same frame names (`stand`, `walk1..3`, `up1..3`,
  `fall`, `roll`, `duck`, `switch1`, `walk5`, `dead`) or edit `_load_frames()` in `player.gd`.
- **Tiles:** `tile_color` on the Main node picks between the Green, Blue, Brown and Yellow tile sets.
  For your own tiles, edit `_tile_texture()` and `_ground_tile()` in `main.gd`.
- **Background:** `scripts/background.gd` takes `set_index` (1–4) for the Kenney background sets.
- **Objects:** each object's sprite paths are at the top of its script in `scripts/objects/`.

## Project layout

```
project.godot          settings (input actions are set up in scripts/game.gd)
scenes/main.tscn       entry scene, which builds the level from text
scenes/player.tscn     the player
scripts/game.gd        global state (autoload "Game"): abilities, orbs, input map, slow-mo
scripts/player.gd      character controller and animation
scripts/main.gd        level builder, lighting, glow
scripts/fx.gd          procedural effects (glows, bursts, rings, afterimages)
scripts/objects/       orbs, keys, doors, shrines, lanterns, enemies, secrets, ...
scripts/sfx.gd         procedural sound effects and music (autoload "Sfx")
tools/shot.gd          dev helper: scripted input and screenshots, for testing movement headlessly
tools/audio_check.gd   dev helper: prints sound levels and saves every sound as a .wav
levels/level1.txt      the level
```

## Exporting

When you export, add `*.txt` under *Resources → Filters to export non-resource files*
in the export preset, so the level file gets included.

Art: [Kenney](https://www.kenney.nl), CC0.
