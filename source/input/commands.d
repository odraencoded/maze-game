import dsfml.window.keyboard;

import geometry;

/++
 + These are the commands used in the game.
 +/
enum Command {
	GoUp, GoDown, GoRight, GoLeft,
	CyclePrevious, CycleNext,
	Grab, Camera, 
	Restart
}

/++
 + This was completely unnecessary.
 +/
enum SystemKey : Keyboard.Key {
	Up     = Keyboard.Key.Up,
	Down   = Keyboard.Key.Down,
	Right  = Keyboard.Key.Right,
	Left   = Keyboard.Key.Left,
	Return = Keyboard.Key.Return,
	Escape = Keyboard.Key.Escape,
} 

/++
 + A conversion table for commands that represent directions
 +/
immutable Side[Command] DIRECTIONAL_COMMANDS;
immutable Side[SystemKey] DIRECTIONAL_KEYS;
static immutable string[Command] BINDING_NAMES;

static this() {
	// Initialize DIRECTIONAL_COMMANDS map
	DIRECTIONAL_COMMANDS[Command.GoUp   ] = Side.Up;
	DIRECTIONAL_COMMANDS[Command.GoRight] = Side.Right;
	DIRECTIONAL_COMMANDS[Command.GoDown ] = Side.Down;
	DIRECTIONAL_COMMANDS[Command.GoLeft ] = Side.Left;
	
	DIRECTIONAL_KEYS[SystemKey.Up   ] = Side.Up;
	DIRECTIONAL_KEYS[SystemKey.Right] = Side.Right;
	DIRECTIONAL_KEYS[SystemKey.Down ] = Side.Down;
	DIRECTIONAL_KEYS[SystemKey.Left ] = Side.Left;
	
	// Initialize BINDING_NAMES map
	BINDING_NAMES[Command.GoUp         ] = "go up";
	BINDING_NAMES[Command.GoRight      ] = "go right";
	BINDING_NAMES[Command.GoDown       ] = "go down";
	BINDING_NAMES[Command.GoLeft       ] = "go left";
	BINDING_NAMES[Command.CyclePrevious] = "cycle previous";
	BINDING_NAMES[Command.CycleNext    ] = "cycle next";
	BINDING_NAMES[Command.Grab         ] = "grab";
	BINDING_NAMES[Command.Camera       ] = "camera";
	BINDING_NAMES[Command.Restart      ] = "restart";
}