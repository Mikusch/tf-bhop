# [TF2] Simple Bunnyhop

This is a simple and lightweight SourceMod plugin for Team Fortress 2 that allows players to bunnyhop.

Unlike most bunnyhop plugins, this one does not manually add velocity, but rather patches out unnecessary checks in the
game's movement code.
It is similar to the bunnyhop found in newer Source engine games, such as Counter-Strike: Global Offensive.

## Features

* Smooth auto-bunnyhopping by holding down the jump button
    * No speed loss on a successful jump
    * Allows jumping while ducked
* Unlimited speed while bunnyhopping
    * Prevents `CTFGameMovement::PreventBunnyJumping` from clamping your speed
* Support for TF2-specific actions in midair (e.g. double jumps, parachutes, grappling hooks, etc.)

## Dependencies

* SourceMod 1.11+
* [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)
* [Source Scramble](https://github.com/nosoop/SMExt-SourceScramble)

## Configuration

The plugin creates the following console variables, configurable in `cfg/sourcemod/plugin.tf-bhop.cfg`:

* `sm_bhop_enabled ( def. "1" )` - When set, allows player speed to exceed maximum running speed.
* `sm_bhop_autojump ( def. "1" )` - When set, players automatically re-jump while holding the jump button.
* `sm_bhop_autojump_falldamage ( def. "0" )` - When set, players will take fall damage while auto-bunnyhopping.
* `sm_bhop_duckjump ( def. "1" )` - When set, allows jumping while ducked.

### Recommended Server Configuration

The following server configuration is recommended for the best experience:

```
sv_airaccelerate 150                // Increase acceleration when in the air
tf_parachute_maxspeed_xy 99999.9f   // Prevent speed clamping when deploying a parachute
```
