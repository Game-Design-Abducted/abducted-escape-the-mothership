extends Control
## =====================================================================
## TITLE / HOME SCREEN. OWNER: Fah. This is the game's main scene.
## =====================================================================
## Right now it shows the finished Homescreen.jpg, with an invisible button
## over the START box it already has (Enter/Space works too).
##
## TODO (Fah, Nov 15):
##   [ ] Rebuild from the layered pieces in assets/home/ (Background, Mountain,
##       Light beam, Star) so they can animate: twinkling stars, beam pulse,
##       UFO bobbing (Spaceship.png)
##   [ ] Start button hover effect + click sound
##   [ ] Title music (assets/audio)

func _ready() -> void:
	$StartButton.pressed.connect(_on_start)
	$StartButton.grab_focus()


func _on_start() -> void:
	GameState.start_new_game()
