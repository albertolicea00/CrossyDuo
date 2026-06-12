# AGENTS.md — Crossy Duo (3D voxel)

Asymmetric co-op game, Crossy Road style. Grid-based movement rendered in a **3D voxel world** (angled orthographic camera, flat-colored low-poly boxes).

> All code, comments, and docs in English, with good meaningful comments.

## Players
- **Player A (Traffic Master):** controls traffic — spawns cars, changes lane speeds.
- **Player B (Crosser):** crosses roads moving on a grid (up/down/left/right, one cell per input).

## Modes
1. **Local (same device):** split touch controls.
2. **Offline LAN (no internet):** host + client over local IP (`ENetMultiplayerPeer`).
3. **Local Server:** host runs an authoritative internal server that controls:
   - car spawning and movement
   - collisions

## Technical requirements
- Godot 4.x (GDScript)
- Web (HTML5) + Android + iOS export
- Grid-based movement (cell snapping: 1 cell = 1 world unit, forward = -Z)
- 3D voxel world: `Node3D` scene, orthographic isometric camera, `BoxMesh` flat-colored visuals (no textures)
- Modular code (logic / networking / UI separated)
- Independent project: standalone repo, nothing shared with the other games

## Art style
3D voxel, low poly cute, cartoon. Flat colors only, mobile-optimized. Original art or CC0.

---

## 🟩 FREE copyright-free assets (CC0)

### 🎨 2D Sprites / Tiles / UI
- Kenney.nl → https://kenney.nl/assets
- Itch.io CC0 Assets → https://itch.io/game-assets/free/tag-cc0
- OpenGameArt (filter CC0) → https://opengameart.org
- CraftPix Free → https://craftpix.net/freebies/
- GameDev Market Free → https://www.gamedevmarket.net/category/free/

### 🔊 Sound and music
- Kenney Audio
- Freesound.org (filter CC0)
- Mixkit
- OpenGameArt Audio

## 🟦 AI-generated assets
- Leonardo.ai, Flux/Midjourney, Stable Diffusion (local)

### Base prompt
> "low poly 3D voxel models, mobile optimized, no textures, only flat colors, CC0 style, clean geometry, cute cartoon style, for a casual game"

---

## Wishlist (not implemented yet)

- **Online multiplayer:** current netcode is LAN-only (ENet over local IP, manual IP entry). Future: dedicated server reachable over the internet + matchmaking/relay. The authority model is already server-side (host validates everything in "Local Server" mode), so the migration path is extracting the host logic into a headless Godot server.
