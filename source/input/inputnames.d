import std.conv;

import dsfml.window.keyboard;

dstring GetKeyName(Keyboard.Key key) {
	return key.to!dstring;
}