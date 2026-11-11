extends Control
## =====================================================================
## END SCREEN (win or lose). OWNER: Fah
## =====================================================================
## Reads GameState.last_result_won.
##   Won  -> "You escaped!" + Main Menu
##   Lost -> "Game Over" + Retry (same level) + Main Menu
##
## TODO (Fah, Nov 15):
##   [ ] Win / lose art (Player_Dead.png for game over? Spaceship flying to Earth for win?)
##   [ ] Sounds

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
