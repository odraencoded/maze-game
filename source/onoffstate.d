import utility;

/++
 + Represents whether something is on or off.
 +/
enum OnOffState {
	Off = 1,
	On = 2,
	Changed = 4,
	
	TurnedOff = Changed | Off,
	TurnedOn = Changed | On
}


/++
 + Whether an state has the OnOffState.On flag
 +/
bool isOn(in OnOffState state) pure nothrow @safe @property {
	return state.hasFlag(OnOffState.On);
}

/++
 + Whether an state has the OnOffState.Changed and OnOffState.On flags
 +/
bool wasTurnedOn(in OnOffState state) pure nothrow @safe @property {
	return state.hasFlag(OnOffState.TurnedOn);
}

/++
 + Whether an state has the OnOffState.Changed and OnOffState.On flags
 +/
bool wasTurnedOff(in OnOffState state) pure nothrow @safe @property {
	return state.hasFlag(OnOffState.TurnedOff);
}