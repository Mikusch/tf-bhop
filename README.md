# Team Fortress 2 Bunnyhop

This is a simple SourceMod plugin that allows players to bunnyhop in Team Fortress 2.

It is different to most other bunnyhop plugins, as it allows you to re-jump before the engine zeroes out
your z-velocity. This makes bunnyhopping feel incedibly smooth, since no speed is lost and no velocity needs to be manually
added by the plugin.

## Features

* Smooth auto-bhop by holding down the jump button
    * No speed loss on a successful jump
    * Works well even with high ping
    * Allows crouch-bhopping
* Unlimited speed while bunnyhopping
    * Prevents `CTFGameMovement::PreventBunnyJumping` from getting called
* Support for multiple jumps in mid-air (e.g. Scout's air dash, halloween spells, etc.)

## Dependencies

* SourceMod 1.10
* [DHooks with Detour Support](https://forums.alliedmods.net/showpost.php?p=2588686&postcount=589)

## ConVars

* `sv_enablebunnyhopping ( def. "1" )` - Allow player speed to exceed maximum running speed
* `sv_autobunnyhopping ( def. "1" )` - Players automatically re-jump while holding jump button

It is recommended to set `sv_airaccelerate` to at least `150` if you intend to use this plugin.
