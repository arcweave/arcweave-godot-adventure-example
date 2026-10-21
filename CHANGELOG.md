# Changelog

All notable changes to Regrets are documented in this file. Each release on GitHub includes `Regrets.zip`, the Godot project with this changelog.

## 2.0.0

The game now runs on **Godot 4.7 .NET** with the C# [Arcweave plugin for Godot](https://github.com/arcweave/arcweave-godot-plugin) v3.1.0. Godot 4 can't export C# projects to the web, so this version is desktop-only. The Godot 3 version is still playable in the browser on [itch.io](https://arcweave.itch.io/regrets), and its code is under the [`godot-3`](https://github.com/arcweave/arcweave-godot-adventure-example/tree/godot-3) tag.

### Changed

- Ported the scenes, scripts and resources from Godot 3.5 and the GDScript plugin to Godot 4.7 and the C# plugin v3.1.0, including its `Story` API and saving.
- Player movement uses Godot 4 navigation through each room's walk area.
- Main connects to the room objects and the inventory itself, instead of those nodes calling the current scene by method name.
- The settings menu is drawn in the game's own screen instead of a separate window, so it stays pixel-crisp and the cursor can leave it.
- The Arcweave plugin ships disabled: Godot can't load a C# plugin before the project is built. The game runs without it; enable it after building to update the story data.
- Speech and title text have a thicker outline, and the credits use tighter paragraph spacing.

### Fixed

- Clicking empty space drops a held inventory item.
- While the verb menu is open, the room and the inventory don't react to the mouse.
- The ending no longer returns to normal play during its fade.
- Saves from the Godot 3 version, and settings files with missing keys, load without errors.
- A specific generic reply now always wins over the fully generic one; before, the winner depended on element order.
- The bedroom walk area no longer goes up into the door.
- A Greek letter in the story text was drawn with a fallback font.
