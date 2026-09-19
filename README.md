# NX Roblox Script

An open-source, multi-game Roblox utility hub built with the Rayfield UI library. Universal tools work everywhere; game-specific tabs appear only when you are inside the matching game.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/exgg1453/NX-Roblox-Script/main/NX-Roblox-Script.lua"))()
```

## Features

### Universal
- **Main:** God Mode, Safe Rollback (anti-death), Anti-Void, Fly (PC + mobile), NoClip, Remove Waves, Anti-AFK
- **Movement:** WalkSpeed / JumpPower locks, Auto Walk / Jump / Spin (spin persists through respawn), Bhop, Anti-Bounce (no wall bounce)
- **Visuals:** Player ESP, Fullbright, FOV, Upside-Down Camera, draggable FPS / Ping / KeyStrokes HUD
- **Combat:** Aimbot, Hitbox, Camera Lock
- **Teleport V2:** saved slots + live player list
- **Blocks:** client-side block placer (square / round / triangle) with color picker, follow platform, directional teleport, click-to-hide walls (local only)
- **Bot:** local client-side bots (spawn multiple, copy a username's avatar or Noob), follow / jump / control (WASD + mobile), POV / third-person / free camera, give sword + local self-only swing test
- **Misc:** local asset & cosmetic spawner (accessory / shirt / pants / face, headless, legless), Join Game by ID, Save Config, Show Place ID

### Game-Specific (auto-detected)
- **Murder Mystery 2:** Role ESP, dropped weapon ESP, death alerts, auto coin collect
- **Speed Escape:** auto step farm, teleports
- **Kick a Lucky Block:** base/block teleport, auto kick loop, income/claim collect, rebirth, speed/weight/kick upgrades, 2x weight bonus
- **Grow a Garden (v1 & v2):** version-aware auto grow / collect (own crops only) / sell, seed buy, night alerts (v2, notification only)

## Notes
- Everything in the Blocks, Bot, and cosmetic sections is **client-side only** — visible to you, not sent to the server, and never affects other players.
- Some games run server-side protection or restrict third-party teleports; this script does not bypass those.

## Platform
Works on PC and mobile with standard Roblox executors.

## License
Licensed under the **Apache License 2.0** — see [LICENSE](LICENSE).

## Author
Made by **NX Team**.
- GitHub: https://github.com/exgg1453
- Repository: https://github.com/exgg1453/NX-Roblox-Script

Open source under Apache 2.0 — feel free to read, learn from, fork, and improve.

## Credits
- **UI:** [Rayfield](https://github.com/SiriusSoftwareLtd/Rayfield) by Sirius Software, used under its own license.
