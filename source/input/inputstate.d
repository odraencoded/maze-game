import std.algorithm;

import dsfml.window.keyboard;
import dsfml.window.mouse;

import inputbinder;
import commands;
import geometry;
import utility;

public import onoffstate;

/++
 + A class to keep track of the user input
 +/
class InputState {
	InputBinder bindings;
	MovingPoint pointer;
	bool close, lostFocus;
	dstring newText;
	
	this(InputBinder bindings) {
		this.bindings = bindings;
		
		_directional_input[OnOffState.Off      ] = Side.None;
		_directional_input[OnOffState.On       ] = Side.None;
		_directional_input[OnOffState.TurnedOff] = Side.None;
		_directional_input[OnOffState.TurnedOn ] = Side.None;
	}
	
	/++
	 + Make the input state good as new.
	 +/
	void reset() pure @safe {
		foreach(ref OnOffState state; _keyStates)
			state = OnOffState.Off;
		
		foreach(ref OnOffState state; _buttonStates)
			state = OnOffState.Off;
		
		foreach(ref Side state; _directional_input)
			state = Side.None;
	}
	
	// Indexing for getting the state of stuff because it is neat.
	OnOffState opIndex(in Command command) const pure {
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
	OnOffState getCommand(in Command command) const pure {
		OnOffState state;
		
		// Get key state
		Keyboard.Key boundKey;
		if(bindings.keys.tryGet(command, boundKey)) {
			state = getKey(boundKey);
			if(state != OnOffState.Off)
				return state;
		}
		
		// If key state is off, return button state
		Mouse.Button boundButton;
		if(bindings.buttons.tryGet(command, boundButton)) {
			state |= getButton(boundButton);
			return state;
		}
		
		// If there is no mouse binding(or key binding) return off.
		return OnOffState.Off;
	}
	
	/++
	 + Gets the state of a keyboard key.
	 +/
	OnOffState getKey(in Keyboard.Key key) const pure {
		return _keyStates.get(key, OnOffState.Off);
	}
	
	/++
	 + Gets the state of a mouse button
	 +/
	OnOffState getButton(in Mouse.Button button) const pure {
		return _buttonStates.get(button, OnOffState.Off);
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
	int getRotation(in OnOffState state) const pure {
		int result;
		if(getCommand(Command.CyclePrevious).hasFlag(state))
			result--;
		if(getCommand(Command.CycleNext).hasFlag(state))
			result++;
		return result;
	}
	
	/++
	 + Prepares state to receive new input.
	 +/
	void prepareCycle() pure @safe {
		// Removing changed flag from input
		foreach(ref OnOffState aKeyState; _keyStates) {
			aKeyState &= ~OnOffState.Changed;
		}
		
		foreach(ref OnOffState aButtonState; _buttonStates) {
			aButtonState &= ~OnOffState.Changed;
		}
		
		close = lostFocus = false;
		
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
		// Update _keyStates
		auto value = key in _keyStates;
		if(value) {
			if(!hasFlag(*value, state))
				*value = OnOffState.Changed | state;
		} else {
			_keyStates[key] = OnOffState.Changed | state;
		}
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
		// Update _buttonStates
		auto value = button in _buttonStates;
		if(value) {
			if(!hasFlag(*value, state))
				*value = OnOffState.Changed | state;
		} else {
			_buttonStates[button] = OnOffState.Changed | state;
		}
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
	void finishCycle() pure {
		// Updating directional input
		foreach(OnOffState keyFlag, ref Side sideInput; _directional_input) {
			sideInput = Side.None;
			foreach(Command sideCommand, Side sideValue; DIRECTIONAL_COMMANDS) {
				if(getCommand(sideCommand).hasFlag(keyFlag))
					sideInput |= sideValue;
			}
		}
	}
	
	private {
		OnOffState[Keyboard.Key] _keyStates;
		OnOffState[Mouse.Button] _buttonStates;
		
		Side[OnOffState] _directional_input;
	}
}