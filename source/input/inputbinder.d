import dsfml.window.keyboard;
import dsfml.window.mouse;

import commands;

/++
 + Stores keyboard keys and mouse buttons bindings to commands.
 +/
class InputBinder {
	Keyboard.Key[Command] keys;
	Mouse.Button[Command] buttons;
}