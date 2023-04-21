# [TF2] Simple Bunnyhop

This is a simple SourceMod plugin for Team Fortress 2 that allows players to bunnyhop.

Unlike most bunnyhop plugins, this one does not manually add velocity, but rather patches out unnecessary checks in the game's movement code.
It is similar to the bunnyhop found in newer Source engine games, such as Counter-Strike: Global Offensive.

## Features

* Smooth auto-bunnyhopping by holding down the jump button
    * No speed loss on a successful jump
    * Allows jumping while ducked
* Unlimited speed while bunnyhopping
    * Prevents `CTFGameMovement::PreventBunnyJumping` from clamping your speed
* Support for TF2-specific actions in midair (e.g. Scout's double jump, B.A.S.E. Jumper parachutes, grappling hooks, etc.)
    * Fully compatible with my [all-class air dash](https://github.com/Mikusch/allclass-air-dash) plugin

## Dependencies

* SourceMod 1.11+
* [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)
* [Source Scramble](https://github.com/nosoop/SMExt-SourceScramble)

## Configuration

The plugin creates the following console variables, configurable in `cfg/sourcemod/plugin.tf-bhop.cfg`:

* `sv_enablebunnyhopping ( def. "1" )` - Allow player speed to exceed maximum running speed
* `sv_autobunnyhopping ( def. "1" )` - Players automatically re-jump while holding jump button
* `sv_duckbunnyhopping ( def. "1" )` - Allow jumping while ducked
* `sv_autobunnyhopping_falldamage ( def. "0" )` - Players can take fall damage while auto-bunnyhopping

### Recommended Server Configuration

The following server configuration is recommended for the best experience:

```
sv_airaccelerate 150                // Increase acceleration when in the air
tf_parachute_maxspeed_xy 99999.9f   // Prevent speed clamping when deploying a parachute
```
