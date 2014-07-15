import std.algorithm;

import dsfml.window.keyboard;

import commands;
import geometry;
import utility;

/++
 + A class to keep track of the user input
 +/
class InputState {
	int[int] bindings;
	
	bool close, lostFocus;
	
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
	
	OnOffState opIndex(in int command) const pure @safe {
		return _command_input[command];
	}
	
	/++
	 + Whether a given command is turned on.
	 +/
	bool isOn(in int command) const pure @safe {
		return _command_input[command].hasFlag(OnOffState.On);
	}
	
	/++
	 + Whether a given command has been turned on this cycle,
	 + e.g. it was off in the previous cycle.
	 +/
	bool wasTurnedOn(in int command) const pure @safe {
		return _command_input[command].hasFlag(OnOffState.TurnedOn);
	}
	
	/++
	 + Whether a given command has been turned off this cycle,
	 + e.g. it was on in the previous cycle.
	 +/
	bool wasTurnedOff(in int command) const pure @safe {
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
	void bind(in int key, in int value) pure nothrow @safe {
		bindings[key] = value;
	}
	
	/++
	 + Prepares state to receive new input.
	 +/
	void prepareCycle() pure @safe {
		// Removing changed flag from input
		foreach(ref OnOffState value; _command_input)
			value &= ~OnOffState.Changed;
		
		close = lostFocus = false;
		
		_changed_key_input.length = 0;
	}
	
	/++
	 + Sets a key as pressed.
	 +/
	void pressKey(in int key) pure @safe {
		int* value = key in bindings;
		if(value && !_command_input[*value].hasFlag(OnOffState.On))
			_command_input[*value] = OnOffState.TurnedOn;
		
		_changed_key_input ~= key;
	}
	
	/++
	 + Sets a key as released.
	 +/
	void releaseKey(in int key) pure @safe {
		int* value = key in bindings;
		if(value && !_command_input[*value].hasFlag(OnOffState.Off))
			_command_input[*value] = OnOffState.TurnedOff;
		
		_changed_key_input ~= key;
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
		// What keyboard keys changed in a cycle
		int[] _changed_key_input;
	}
}