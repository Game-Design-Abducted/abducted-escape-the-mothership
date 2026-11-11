extends Control
## End screen (win or lose). Ploy's.
##
## Reads GameState.last_result_won.
##   won  -> "You escaped!" + Main Menu
##   lost -> "Game Over" + Retry (same level) + Main Menu
##
## TODO Ploy (ask Fah for the art and sounds):
##  - win / lose art (Player_Dead.png for game over? spaceship flying to Earth for the win?)
##  - sounds

func _ready() -> void:
	var won := GameState.last_result_won
	$VBox/Title.text = "YOU ESCAPED!" if won else "GAME OVER"
	$VBox/Subtitle.text = "Welcome home, astronaut." if won else "The aliens got you on level %d." % GameState.current_level
	$VBox/RetryButton.visible = not won
	$VBox/RetryButton.pressed.connect(GameState.retry_level)
	$VBox/MenuButton.pressed.connect(func(): GameState.goto("title"))
	if won:
		$VBox/MenuButton.grab_focus()
	else:
		$VBox/RetryButton.grab_focus()
