import dsfml.graphics;

alias Point = Vector2!int;

class Game {
	RenderWindow window;
	bool isRunning;
	
	Stage stage;
}

enum OnOffState {
	Off = 0, On = 1,
	Changed = 2,
	
	TurnedOff = Changed | Off,
	TurnedOn = Changed | On
}

class Stage {
	Pusher player;
}

class Pusher {
	Point position;
}