import commands;
import geometry;
import utility;

/++
 + A class to keep track of the user input
 +/
class InputState {
	int[int] bindings;
	
	bool close;
	
	this() {
		_input = new OnOffState[Command.max + 1];
		
		_directional_input[OnOffState.Off      ] = Side.None;
		_directional_input[OnOffState.On       ] = Side.None;
		_directional_input[OnOffState.TurnedOff] = Side.None;
		_directional_input[OnOffState.TurnedOn ] = Side.None;
	}
	
	/++
	 + Make the input state good as new.
	 +/
	void reset() pure @safe {
		foreach(ref OnOffState state; _input)
			state = OnOffState.Off;
		
		foreach(ref Side state; _directional_input)
			state = Side.None;
	}
	
	OnOffState opIndex(in int command) const pure @safe {
		return _input[command];
	}
	
	/++
	 + Whether a given command is turned on.
	 +/
	bool isOn(in int command) const pure @safe {
		return _input[command].hasFlag(OnOffState.On);
	}
	
	/++
	 + Whether a given command has been turned on this cycle,
	 + e.g. it was off in the previous cycle.
	 +/
	bool wasTurnedOn(in int command) const pure @safe {
		return _input[command].hasFlag(OnOffState.TurnedOn);
	}
	
	/++
	 + Whether a given command has been turned off this cycle,
	 + e.g. it was on in the previous cycle.
	 +/
	bool wasTurnedOff(in int command) const pure @safe {
		return _input[command].hasFlag(OnOffState.TurnedOff);
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
	 + Returns -1 if CyclePrevious are state.
	 + Returns  1 if CycleNext are state.
	 + Returns  0 if either or both are state.
	 +/
	int getRotation(in OnOffState state) const pure @safe {
		int result;
		if(_input[Command.CyclePrevious].hasFlag(state))
			result--;
		if(_input[Command.CycleNext].hasFlag(state))
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
		foreach(ref OnOffState value; _input)
			value &= ~OnOffState.Changed;
		
		close = false;
	}
	
	/++
	 + Sets a key as pressed.
	 +/
	void pressKey(in int key) pure @safe {
		int* value = key in bindings;
		if(value && !_input[*value].hasFlag(OnOffState.On))
			_input[*value] = OnOffState.TurnedOn;
	}
	
	/++
	 + Sets a key as released.
	 +/
	void releaseKey(in int key) pure @safe {
		int* value = key in bindings;
		if(value && !_input[*value].hasFlag(OnOffState.Off))
			_input[*value] = OnOffState.TurnedOff;
	}
	
	/++
	 + Fills remaining input data from the input received during this cycle.
	 +/
	void finishCycle() pure @safe {
		// Updating directional input
		foreach(OnOffState keyFlag, ref Side sideInput; _directional_input) {
			sideInput = Side.None;
			foreach(int sideCommand, Side sideValue; DIRECTIONAL_COMMANDS) {
				if(_input[sideCommand].hasFlag(keyFlag))
					sideInput |= sideValue;
			}
		}
	}
	
	private {
		OnOffState[] _input;
		Side[OnOffState] _directional_input;
	}
}