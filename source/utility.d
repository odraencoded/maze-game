bool hasFlag(T)(const T value, const T flag) pure nothrow @safe {
	return (value & flag) == flag;
}