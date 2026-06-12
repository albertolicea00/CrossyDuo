# TODO — Crossy Duo

Living checklist. Items are checked (`[x]`) when done — never deleted.

## Project setup

- [x] Godot 4.x project (`project.godot`, GL Compatibility renderer for Web + Android + iOS)
- [x] Entry scene `scenes/main.tscn` + code-built UI
- [x] `Net` autoload (`scripts/net.gd`) — LOCAL / HOST / CLIENT, port 7802
- [x] Repo files: README, LICENSE, EULA, PRIVACY_POLICY, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, AGENTS.md, TODO.md, .github templates, .gitignore

## Core gameplay

- [x] Grid movement: one cell per input, tween hop (`scripts/crosser.gd`)
- [x] Procedural rows: grass/road mix, max 3 consecutive roads
- [x] Cars: per-lane direction + speed, ambient auto-spawn timers
- [x] Traffic Master: tap lane to spawn car (1.5s cooldown), Lane +/- speed buttons
- [x] Authoritative collision: car vs crosser (same row + x overlap)
- [x] 3D voxel aesthetic: Node3D world, orthographic isometric camera, voxel chick + cars, ground-plane ray picking for lane taps
- [x] Camera follows crosser upward; score = furthest row
- [x] Game over panel + restart + back to menu

## Modes

- [x] Local (same device): left half = Crosser swipe/tap, right half = Traffic Master
- [x] Offline LAN: host + client by IP (`ENetMultiplayerPeer`)
- [x] Local Server: strict host-side validation (cooldown, lane range)
- [x] State sync: unreliable snapshot (crosser + all cars) + reliable row/speed/restart RPCs

## Polish / pending

- [x] Automated smoke playtest (`tests/playtest.tscn`): play → die → game over → restart loop verified headless
- [ ] Manual playtest: balance lane speeds, spawn rates, road density
- [ ] LAN playtest on two devices
- [ ] Idle pressure mechanic (eagle/timer punishing camping)
- [ ] River rows with logs (classic Crossy Road variety)
- [ ] Sound effects (hop, car horn, crash) — CC0 or original
- [ ] Background music — CC0 or original
- [ ] Lane highlight feedback when Traffic Master selects a row
- [ ] Pause menu
- [ ] High score persistence (local save)
- [ ] Web export preset + test in browser
- [ ] Android + iOS export presets + test on device
- [ ] App icon final art + splash screen

## Wishlist

- [ ] Online multiplayer: dedicated headless server + matchmaking/relay
- [ ] Role swap option (host as Traffic Master)
- [ ] Multiple crosser characters (cosmetic)
