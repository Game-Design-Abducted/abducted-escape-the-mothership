extends Node
## Global event bus (autoload, use it as `Events`).
## Shared file, ask Ploy before adding a signal.
##
## The point: instead of calling into someone else's script, emit a signal
## here and let whoever cares listen for it.
##   Events.enemy_killed.emit(self)
##   Events.enemy_killed.connect(_on_enemy_killed)
##
## The comment above each group says who emits it. Anyone can listen.
## Godot will warn about "unused signal" in this file, just ignore that.

# ---- Player (emitted by Yang's player.gd) ----
signal player_hp_changed(hp: int, max_hp: int)   ## HUD hearts listen to this
signal player_died

# ---- Enemies (emitted by Ploy's enemy.gd / wave_manager.gd) ----
signal enemy_killed(enemy: Node)                 ## LaserManager counts these to charge the laser
signal enemy_hit(enemy: Node)                    ## took damage but is still alive (tanks)
signal enemy_blocked(enemy: Node)                ## a bullet hit it while it was still hatching (no damage)
signal enemy_spawned(enemy: Node)                ## a monster just came out of the origin
signal wave_started(wave_number: int)

# ---- Laser (emitted by Yang's laser_manager.gd) ----
signal laser_spawned(position: Vector2)          ## HUD: "Laser available!"
signal laser_picked_up                           ## gameplay freezes and aim mode starts
signal laser_fired(hit: bool)                    ## hit = origin destroyed, miss = retry later
signal laser_charge_changed(kills: int, kills_needed: int)   ## laser charges from kills

# ---- Origin (emitted by Ploy's origin.gd) ----
signal origin_destroyed

# ---- Level flow (emitted by Kong's game_state.gd) ----
signal time_changed(seconds_left: float)         ## HUD timer listens
signal level_started(level_number: int)
signal level_finished(won: bool)
