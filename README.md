# Team Fortress 2 Bunnyhopping
This is a simple plugin allowing players to bunnyhop in Team Fortress 2.

Unlike many other plugins, this implementation will preserve 100% of your speed instead of manually adding lost velocity whenever you touch the ground.
This ensures smooth bunnyhopping even on higher latencies since the server will never report your z-velocity as zero.

Additionally, this plugin suppresses the call to `CTFGameMovement::PreventBunnyJumping` to prevent your maximum speed from getting capped.

## Features
- Automatic bunnyhopping by holding the jump button
- No velocity loss
- No artificial velocity gain
- Compatibility with Scout's double jump (and [this plugin](https://github.com/Mikusch/air-dash) too)

## ConVars
- `sv_enablebunnyhopping ( def. "1" )` - Allow player speed to exceed maximum running speed
- `sv_autobunnyhopping ( def. "1" )` - Players automatically re-jump while holding jump button

It is recommended to set `sv_airaccelerate` to at least `150` when using this plugin.
