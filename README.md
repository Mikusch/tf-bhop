# Team Fortress 2 Bunnyhopping

This is a simple SourceMod plugin that allows players to bunnyhop in Team Fortress 2.

Unlike most other bunnyhop plugins, this implementation makes you jump before the engine zeroes out your z-velocity, preserving 100% of your speed and making each jump feel buttery smooth.

## Features

* Smooth auto-bunnyhopping by holding down the jump button
    * No speed loss on a successful jump
    * Works well even with high ping
    * Allows jumping while ducked
* Unlimited speed while bunnyhopping
    * Prevents `CTFGameMovement::PreventBunnyJumping` from getting called
* Support for multiple jumps in mid-air (e.g. Scout's air dash, halloween spells, etc.)
    * Fully compatible with my [all-class air dash](https://github.com/Mikusch/air-dash) plugin

## Dependencies

* SourceMod 1.10
* [MemoryPatch](https://github.com/Kenzzer/MemoryPatch) (compile only)

## ConVars

* `sv_enablebunnyhopping ( def. "1" )` - Allow player speed to exceed maximum running speed
* `sv_autobunnyhopping ( def. "1" )` - Players automatically re-jump while holding jump button
* `sv_duckbunnyhopping ( def. "1" )` - Allow jumping while ducked

It is recommended to set `sv_airaccelerate` to at least `150` if you intend to use this plugin.
