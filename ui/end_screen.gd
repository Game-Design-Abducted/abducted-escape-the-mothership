extends Control
## End screen (win or lose). Ploy's.
##
## Reads GameState.last_result_won.
##   won  -> spaceship + "You escaped!" + win sound + Main Menu
##   lost -> hurt astronaut + "Game Over" + lose sound + Retry (same level) + Main Menu
##
## TODO Ploy:
##  - swap in real win / lose art if Fah draws some (set it on VBox/Art below)

const WIN_ART := preload("res://assets/sprites/Spaceship.png")
const LOSE_ART := preload("res://assets/sprites/Player_Hit.png")
const WIN_SOUND := preload("res://assets/audio/sfx/win.wav")
const LOSE_SOUND := preload("res://assets/audio/sfx/lose.wav")

func _ready() -> void:
	var won := GameState.last_result_won
	$VBox/Title.text = "YOU ESCAPED!" if won else "GAME OVER"
	$VBox/Subtitle.text = "Welcome home, astronaut." if won else "The aliens got you on level %d." % GameState.current_level
	$VBox/Art.texture = WIN_ART if won else LOSE_ART
	$Jingle.stream = WIN_SOUND if won else LOSE_SOUND
	$Jingle.play()
	$VBox/RetryButton.visible = not won
	$VBox/RetryButton.pressed.connect(GameState.retry_level)
	$VBox/MenuButton.pressed.connect(func(): GameState.goto("title"))
	if won:
		$VBox/MenuButton.grab_focus()
	else:
		$VBox/RetryButton.grab_focus()
