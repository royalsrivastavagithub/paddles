# Paddles

A fast, polished Pong-style game built with the LÖVE 2D engine.

## Overview

`Paddles` is a local multiplayer and single-player Pong recreation featuring:
- Singleplayer mode with adjustable difficulty
- Local multiplayer mode
- Bot vs Bot mode
- In-game settings for controls, display, and gameplay
- Customizable paddle, ball, and UI settings

## Features

- Classic Pong gameplay with responsive paddle and ball physics
- Multiple difficulties: Easy, Medium, Hard, God
- Split controller support for shared gamepads
- Mouse control option for Player 1
- Adjustable ball speed, winning score, and frame limiter
- Resolution and fullscreen settings

## Installation

1. Install [LÖVE](https://love2d.org/) version 11.0 or later.
2. Clone or download the repository.
3. Open the project folder in your terminal.

## Running the Game

From the project root folder, run:

```bash
love .
```

If your system does not recognize `love`, use the full path to the LÖVE executable.

## Controls

### Menu Navigation
- `Up` / `Down` arrows: move menu selection
- `Enter` or `Space`: confirm selection
- `Escape`: quit from the menu
- Gamepad `DPAD` and `A` buttons are supported

### Player Controls
- Player 1: `W` = up, `S` = down
- Player 2: `Up Arrow` = up, `Down Arrow` = down
- If a gamepad is connected, Player 1 can also use the left stick or D-Pad.
- With split controller enabled, both paddles can share the same gamepad.

### In-Game Pause
- `Escape` or gamepad `Start` / `B` (depending on context) to pause / return

## Settings

The settings screen allows you to customize:
- Paddle sensitivity
- Ball speed
- Winning score
- Display mode (Windowed / Fullscreen)
- Resolution
- VSync
- Maximum FPS
- Split controller mode
- Mouse control
- Font / UI scale
- Color sliders for background, menu, paddles, ball, and score display

## Project Structure

- `main.lua` — main game loop and state manager
- `conf.lua` — LÖVE window settings
- `src/menu.lua` — main menu logic and drawing
- `src/game/init.lua` — game state and update loop
- `src/game/entities.lua` — paddle and ball physics
- `src/settings.lua` — settings menu and value binding
- `src/input.lua` — keyboard and gamepad input handling
- `src/aiselect.lua` — bot difficulty selection menu
- `assets/fonts/font.ttf` — game font asset

## Notes

- The game uses a virtual resolution of `1280x720`.
- `pong v0.9` is shown in the menu footer.
- The repository is designed to run directly in LÖVE without additional build steps.

## License

This project does not include a license file. Add one if you want to clarify reuse terms.
