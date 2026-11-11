extends Node
## =====================================================================
## EVENTS (EventBus): autoload, available everywhere as `Events`
## OWNER: shared, gatekept by Ploy (integrator). Ask Ploy before adding a signal.
## =====================================================================
## Use this so nobody has to call into someone else's code directly.
##
##   Emit:    Events.enemy_killed.emit(self)
##   Listen:  Events.enemy_killed.connect(_on_enemy_killed)
##
## Who emits each signal is noted in the comment. Anyone can listen.
## (Godot warns about "unused signal" here. That warning is expected.)

# ---- Player (emitted by Yang's player.gd) ----
signal player_hp_changed(hp: int, max_hp: int)   ## HUD hearts listen to this
signal player_died

# ---- Enemies (emitted by Ploy's enemy.gd / wave_manager.gd) ----
signal enemy_killed(enemy: Node)                 ## LaserManager can count kills
signal wave_started(wave_number: int)

# ---- Laser (emitted by Kong's laser_manager.gd) ----
signal laser_spawned(position: Vector2)          ## HUD: "Laser available!"
signal laser_picked_up                           ## gameplay freezes and aim mode starts
signal laser_fired(hit: bool)                    ## hit = origin destroyed, miss = retry later
signal laser_countdown_changed(seconds_left: float)

# ---- Origin (emitted by Kong's origin.gd) ----
signal origin_destroyed

# ---- Level flow (emitted by Kong's game_state.gd) ----
signal time_changed(seconds_left: float)         ## HUD timer listens
signal level_started(level_number: int)
signal level_finished(won: bool)
