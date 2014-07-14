import geometry;

/++
 + These are the commands used in the game.
 +/
enum Command {
	GoUp, GoDown, GoRight, GoLeft,
	CyclePrevious, CycleNext,
	Grab, Camera, 
}

/++
 + A conversion table for commands that represent directions
 +/
immutable Side[Command] DIRECTIONAL_COMMANDS;

static this() {
	// Initialize DIRECTIONAL_COMMANDS map
	DIRECTIONAL_COMMANDS[Command.GoUp   ] = Side.Up;
	DIRECTIONAL_COMMANDS[Command.GoRight] = Side.Right;
	DIRECTIONAL_COMMANDS[Command.GoDown ] = Side.Down;
	DIRECTIONAL_COMMANDS[Command.GoLeft ] = Side.Left;
}