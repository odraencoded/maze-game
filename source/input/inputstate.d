import std.algorithm;

import dsfml.window.keyboard;
import dsfml.window.mouse;

import commands;
import geometry;
import utility;

/++
 + A class to keep track of the user input
 +/
class InputState {
	Command[Keyboard.Key] keyBindings;
	Command[Mouse.Button] buttonBindings;
	MovingPoint pointer;
	bool close, lostFocus;
	dstring newText;
	
	this() {
		_command_input = new OnOffState[Command.max + 1];
		
		_directional_input[OnOffState.Off      ] = Side.None;
		_directional_input[OnOffState.On       ] = Side.None;
		_directional_input[OnOffState.TurnedOff] = Side.None;
		_directional_input[OnOffState.TurnedOn ] = Side.None;
	}
	
	/++
	 + Make the input state good as new.
	 +/
	void reset() pure @safe {
		foreach(ref OnOffState state; _command_input)
			state = OnOffState.Off;
		
		foreach(ref Side state; _directional_input)
			state = Side.None;
	}
	
	// Indexing for getting the state of stuff because it is neat.
	OnOffState opIndex(in Command command) const pure @safe {
		return getCommand(command);
	}
	OnOffState opIndex(in Keyboard.Key key) const {
		return getKey(key);
	}
	OnOffState opIndex(in Mouse.Button button) const {
		return getButton(button);
	}
	
	/++
	 + Gets the state of a command
	 +/
	OnOffState getCommand(in Command command) pure const @safe {
		return _command_input[command];
	}
	
	/++
	 + Gets the state of a keyboard key.
	 +/
	OnOffState getKey(in Keyboard.Key key) const {
		if(Keyboard.isKeyPressed(key)) {
			if(canFind(_changed_key_input, key)) return OnOffState.TurnedOn;
			else return OnOffState.On;
		} else {
			if(canFind(_changed_key_input, key)) return OnOffState.TurnedOff;
			else return OnOffState.Off;
		}
	}
	
	/++
	 + Gets the state of a mouse button
	 +/
	OnOffState getButton(in Mouse.Button button) const  {
		if(Mouse.isButtonPressed(button)) {
			if(canFind(_changed_button_input, button))
				return OnOffState.TurnedOn;
			else return OnOffState.On;
		} else {
			if(canFind(_changed_button_input, button))
				return OnOffState.TurnedOff;
			else return OnOffState.Off;
		}
	}
	
	/++
	 + Whether a given command is turned on.
	 +/
	bool isOn(in Command command) const pure @safe {
		return _command_input[command].hasFlag(OnOffState.On);
	}
	
	/++
	 + Whether a given command has been turned on this cycle,
	 + e.g. it was off in the previous cycle.
	 +/
	bool wasTurnedOn(in Command command) const pure @safe {
		return _command_input[command].hasFlag(OnOffState.TurnedOn);
	}
	
	/++
	 + Whether a given command has been turned off this cycle,
	 + e.g. it was on in the previous cycle.
	 +/
	bool wasTurnedOff(in Command command) const pure @safe {
		return _command_input[command].hasFlag(OnOffState.TurnedOff);
	}
	
	/++
	 + Returns which sides of the directional input are in the given state.
	 +/
	Side getSides(in OnOffState state) const pure @safe {
		return _directional_input[state];
	}
	
	/++
	 + Returns a Point representing the directional offset.
	 +/
	Point getOffset(in OnOffState state) const pure @safe {
		return _directional_input[state].getOffset();
	}
	
	/++
	 + Same stuff as above but with keys.
	 +/
	bool isKeyOn(in Keyboard.Key key) const {
		return getKey(key).hasFlag(OnOffState.On);
	}
	
	bool wasKeyTurnedOn(in Keyboard.Key key) const {
		return getKey(key).hasFlag(OnOffState.TurnedOn);
	}
	
	bool wasKeyTurnedOff(in Keyboard.Key key) const {
		return getKey(key).hasFlag(OnOffState.TurnedOff);
	}
	
	/++
	 + Same stuff as above but with buttons.
	 +/
	bool isButtonOn(in Mouse.Button button) const {
		return getButton(button).hasFlag(OnOffState.On);
	}
	
	bool wasButtonTurnedOn(in Mouse.Button button) const {
		return getButton(button).hasFlag(OnOffState.TurnedOn);
	}
	
	bool wasButtonTurnedOff(in Mouse.Button button) const {
		return getButton(button).hasFlag(OnOffState.TurnedOff);
	}
	
	Side getSystemSides(in OnOffState state) const {
		Side result;
		foreach(Keyboard.Key aKey, Side aSide; DIRECTIONAL_KEYS) {
			if(getKey(aKey).hasFlag(state))
				result |= aSide;
		}
		return result;
	}
	
	Point getSystemOffset(in OnOffState state) const {
		return getSystemSides(state).getOffset();
	}
	
	/++
	 + Returns -1 if CyclePrevious are state.
	 + Returns  1 if CycleNext are state.
	 + Returns  0 if either or both are state.
	 +/
	int getRotation(in OnOffState state) const pure @safe {
		int result;
		if(_command_input[Command.CyclePrevious].hasFlag(state))
			result--;
		if(_command_input[Command.CycleNext].hasFlag(state))
			result++;
		return result;
	}
	
	/++
	 + Binds a keyboard key to a given command.
	 +/
	void bind(in Keyboard.Key key, in Command value) pure nothrow @safe {
		keyBindings[key] = value;
	}
	
	/++
	 + Prepares state to receive new input.
	 +/
	void prepareCycle() pure @safe {
		// Removing changed flag from input
		foreach(ref OnOffState value; _command_input)
			value &= ~OnOffState.Changed;
		
		close = lostFocus = false;
		
		// Clear changed key/button
		_changed_key_input.length = 0;
		_changed_button_input.length = 0;
		
		// Clear text input
		newText = "";
	}
	
	/++
	 + Turns a key on or off.
	 + State should be either On or Off. Duh.
	 +/
	void turnKey(in Keyboard.Key key, OnOffState state) pure @safe
	in { assert(state == OnOffState.On || state == OnOffState.Off); }
	body {
		// Update _command_input if the key is bound to something
		Command* value = key in keyBindings;
		if(value) {
			auto commandValue = &_command_input[*value];
			// The command must not be <state> already
			if(!hasFlag(*commandValue, state))
				*commandValue = OnOffState.Changed | state;
		}
		
		// Set the key as changed
		_changed_key_input ~= key;
	}
	
	/++
	 + Sets a key as pressed.
	 +/
	void pressKey(in Keyboard.Key key) pure @safe {
		turnKey(key, OnOffState.On);
	}
	
	/++
	 + Sets a key as released.
	 +/
	void releaseKey(in Keyboard.Key key) pure @safe {
		turnKey(key, OnOffState.Off);
	}
	
	/++
	 + Mouse button equivalent of turnKey
	 +/
	void turnButton(in Mouse.Button button, OnOffState state) pure @safe
	in { assert(state == OnOffState.On || state == OnOffState.Off); }
	body {
		// Update _command_input if the button is bound to something
		Command* value = button in buttonBindings;
		if(value) {
			auto commandValue = &_command_input[*value];
			// The command must not be <state> already
			if(!hasFlag(*commandValue, state))
				*commandValue = OnOffState.Changed | state;
		}
		
		// Set the key as changed
		_changed_button_input ~= button;
	}
	
	/++
	 + Sets a button as pressed.
	 +/
	void pressButton(in Mouse.Button button) pure @safe {
		turnButton(button, OnOffState.On);
	}
	
	/++
	 + Sets a button as pressed.
	 +/
	void releaseButton(in Mouse.Button button) pure @safe {
		turnButton(button, OnOffState.Off);
	}
	
	/++
	 + Fills remaining input data from the input received during this cycle.
	 +/
	void finishCycle() pure @safe {
		// Updating directional input
		foreach(OnOffState keyFlag, ref Side sideInput; _directional_input) {
			sideInput = Side.None;
			foreach(int sideCommand, Side sideValue; DIRECTIONAL_COMMANDS) {
				if(_command_input[sideCommand].hasFlag(keyFlag))
					sideInput |= sideValue;
			}
		}
	}
	
	private {
		OnOffState[] _command_input;
		Side[OnOffState] _directional_input;
		
		// What keyboard keys and mouse buttons changed in a cycle
		Keyboard.Key[] _changed_key_input;
		Mouse.Button[] _changed_button_input;
	}
}