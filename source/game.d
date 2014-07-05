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

enum Side {
	None        = 0,
	Top         = 1,
	TopRight    = 2,
	Right       = 4,
	BottomRight = 8,
	Bottom      = 16,
	BottomLeft  = 32,
	Left        = 64,
	TopLeft     = 128,
	
	Up = Top,
	Down = Bottom,
	
	Vertical = Top | Bottom,
	Horizontal = Left | Right,
}

class Stage {
	Pusher player;
	Wall[] walls;
}

class Pusher {
	Point position;
	Side facing = Side.Down;
}

class Wall {
	Point position;
	Point[] blocks;
}