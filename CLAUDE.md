# CLAUDE.md

Persistent context for working on this repository. Read this before making changes.

## What this is

NX Roblox Script — an open-source, multi-game utility hub for Roblox, written in Luau and built on the Rayfield UI library. It loads through a Roblox executor via `loadstring`. Universal tools work everywhere; game-specific tabs appear only when the player is inside a supported game.

- Main file: `NX-Roblox-Script.lua` (single file, whole hub lives here).
- UI: Rayfield (`CreateWindow`, `CreateTab`, `CreateToggle`, `CreateButton`, `CreateSlider`, `CreateDropdown`, `CreateInput`, `CreateColorPicker`, `Rayfield:Notify`).
- Loader: `loadstring(game:HttpGet("https://raw.githubusercontent.com/exgg1453/NX-Roblox-Script/main/NX-Roblox-Script.lua"))()`

## Validate before every commit (IMPORTANT)

No build step. Check Lua syntax with a parser. Standard `luac5.4` does NOT understand Luau, so strip the Luau-only tokens first:

```bash
cp NX-Roblox-Script.lua /tmp/check.lua
sed -i 's/\bcontinue\b//g; s/+=/=/g; s/-=/=/g; s/\*=/=/g' /tmp/check.lua
luac5.4 -p /tmp/check.lua    # must exit 0
```

Two recurring pitfalls:
- `...` inside an inner `pcall(function() ... end)` closure fails — capture `local args = {...}` first, then `table.unpack(args)`.
- Lua's "too many local variables (limit 200) in main function": the file is near the cap. Wrap new self-contained sections in `do ... end` so their locals free at the end, and avoid `local X = Tab:Create...` captures you never reuse.

## Architecture / conventions

- Game tabs are gated near the top by a `*_PLACE_IDS` table; Grow a Garden also falls back to matching `game.Name` (`placeMatches`) and detects v1 vs v2.
- Shared helpers after the services block: `copyToClipboard`, `guiButton(...)`, `clickGuiButton(btn)`.
- Game features fire the game's REAL remotes/GUI buttons found via the in-script "Scan ... (Copy to Clipboard)" diagnostics.

## Code style

- English code, no comments unless explicitly requested, never abbreviated.
- Concise English notifications/labels.

## Git

- GitHub: `exgg1453`. Brand: NX Team.
- Commit messages in English: short + specific for a fix, `Update` for general changes.
- Never commit tokens.

## Design boundaries (intentional)

- In scope: single-player / self-only automation, and client-side-only features (blocks, bots, cosmetics) that are visible to the user alone and never replicate to the server or affect other players.
- Not in scope: tools that automatically harm other real players in PvP, stealing from other players' gardens, or bypassing a game's anti-cheat / platform restrictions (e.g. teleport error 773). Auto-collect skips "Steal" prompts; bot combat targets only the local player.

## Supported games (PlaceIds)

- MM2: 142823291
- Speed Escape: 95082159892680
- Kick a Lucky Block: 89469502395769
- Grow a Garden 1: 124977557560410, 126884695634066
- Grow a Garden 2: 77085202503540, 97598239454123
