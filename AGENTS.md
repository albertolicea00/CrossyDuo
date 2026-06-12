# AGENTS.md — Crossy Duo (2D)

2D asymmetric co-op game, Crossy Road style. Grid-based movement.

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
- Web + Android export
- Grid-based movement (cell snapping)
- Voxel/cartoon art
- Modular code (logic / networking / UI separated)
- Independent project: do NOT share anything with the other games in the monorepo

## Art style
Voxel, low poly cute, cartoon. Original art or CC0.

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
> "2D game assets, flat style, clean shapes, no gradients, CC0 style, simple silhouettes, bright colors, for a mobile game, voxel cute style"

---

## Wishlist (not implemented yet)

- **Online multiplayer:** current netcode is LAN-only (ENet over local IP, manual IP entry). Future: dedicated server reachable over the internet + matchmaking/relay. The authority model is already server-side (host validates everything in "Local Server" mode), so the migration path is extracting the host logic into a headless Godot server.
