extends Control
## Title / home screen. Fah's. This is the game's main scene.
##
## For now it shows the finished Homescreen.jpg with an invisible button over
## the START box that's already in the picture (Enter/Space works too).
##
## TODO Fah:
##  - rebuild it from the layered pieces in assets/home/ (Background, Mountain,
##    Light beam, Star) so they can animate: twinkling stars, pulsing beam,
##    UFO bobbing (Spaceship.png)
##  - start button hover effect + click sound
##  - title music (assets/audio)

func _ready() -> void:
	$StartButton.pressed.connect(_on_start)
	$StartButton.grab_focus()


func _on_start() -> void:
	GameState.start_new_game()
