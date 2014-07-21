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
 + Tries to get a value from key in an array.
 + Returns false if the key is not in the array.
 +/
bool tryGet(K, V)(in V[K] array, in K key, ref V result) pure nothrow @safe {
	auto pointer = key in array;
	if(pointer is null)
		return false;
	
	result = *pointer;
	return true;
}