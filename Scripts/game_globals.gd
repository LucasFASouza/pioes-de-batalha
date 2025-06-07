extends Node

var game_config = {
	"player2_mode": "human",  # "human", "ai_basic", "ai_aggressive", "ai_deceiver"
	"points_to_win": 5
}

func get_ai_personality_from_mode(mode: String) -> int:
	match mode:
		"ai_basic":
			return 0  # Runner
		"ai_aggressive":
			return 1  # Aggressive
		"ai_deceiver":
			return 2  # Deceiver
		_:
			return 0  # Default to runner

