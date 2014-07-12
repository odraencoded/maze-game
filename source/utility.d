/**
 * Returns whether a bitflag flag is set in value.
 */
bool hasFlag(T)(const T value, const T flag) pure nothrow @safe {
	return (value & flag) == flag;
}

/**
 * Returns an array of ints each representing a bit flag set in value.
 */
int[] getFlags(T)(const T value) pure nothrow @safe {
	int[] foundFlags;
	for(int i = 1; i < T.max; i *= 2) {
		if(value.hasFlag!int(i))
			foundFlags ~= i;
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