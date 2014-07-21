/**
 * Returns whether a bitflag flag is set in value.
 */
bool hasFlag(in int value, in int flag) pure nothrow @safe {
	return (value & flag) == flag;
}

/**
 * Returns an array of T each representing a bit flag set in value.
 */
T[] getFlags(T)(in T value) pure nothrow {
	T[] foundFlags;
	for(int i = 1; i < T.max; i *= 2) {
		if(value.hasFlag(i))
			foundFlags ~= cast(T)i;
	}
	return foundFlags;
}

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