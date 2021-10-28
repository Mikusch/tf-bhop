# Team Fortress 2 Bunnyhop

This is a simple SourceMod plugin that allows players to bunnyhop in Team Fortress 2.

Unlike most other bunnyhop plugins, this implementation makes you jump before the engine zeroes out your z-velocity,
preserving 100% of your speed and making each jump feel buttery smooth.

## Features

* Smooth auto-bunnyhopping by holding down the jump button
    * No speed loss on a successful jump
    * Works well even with high ping
    * Allows jumping while ducked
* Unlimited speed while bunnyhopping
    * Prevents `CTFGameMovement::PreventBunnyJumping` from clamping your speed
* Support for TF2-specific actions in mid-air (e.g. Scout's air dash, B.A.S.E. Jumper parachute, grappling hooks, etc.)
    * Fully compatible with my [all-class air dash](https://github.com/Mikusch/air-dash) plugin

## Dependencies

* SourceMod 1.10+
* [MemoryPatch](https://github.com/Kenzzer/MemoryPatch) (compile only)

## ConVars

The plugin creates the following console variables, configurable in `cfg/sourcemod/plugin.tf-bhop.cfg`:

* `sv_enablebunnyhopping ( def. "1" )` - Allow player speed to exceed maximum running speed
* `sv_autobunnyhopping ( def. "1" )` - Players automatically re-jump while holding jump button
* `sv_duckbunnyhopping ( def. "1" )` - Allow jumping while ducked
* `sv_autobunnyhopping_falldamage ( def. "0" )` - Players can take fall damage while auto-bunnyhopping

### Recommended Configuration

I recommend the following server configuration for a smooth experience. These are personal preference, so choose values that you are comfortable with:

```
sv_airaccelerate 150                // Increase acceleration when in the air
tf_parachute_maxspeed_xy 99999.9f   // Prevent speed clamping when deploying a parachute
```
