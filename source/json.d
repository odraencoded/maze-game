public import std.json;

/**
 * JSON utilities because std.json is a pain in the ass to use.
 */


/**
 * Gets object[key] and converts it to the appropriate type of result.
 * Returns true on success.
 */
bool getJsonValue(K, V)(JSONValue[K] object, in K key, ref V result) {
	JSONValue* value = key in object;
	if(!(value is null))
		return getJsonValue(*value, result);
	return false;
}

/**
 * Fills result with data from an array in object[key]
 * Returns true on success.
 */
bool getJsonValues(T, V)(JSONValue[T] object, in T key, ref V[] result) {
	JSONValue[] values;
	if(getJsonValue(object, key, values)) {
		result.length = values.length;
		foreach(int i, ref JSONValue aValue; values) {
			if(!getJsonValue(aValue, result[i]))
				return false;
		}
		
		return true;
	}
	return false;
}


/**
 * Fills result with data from the array object
 * Returns true on success.
 */
bool getJsonValues(T)(JSONValue object, ref T[] result) {
	JSONValue[] values;
	if(getJsonValue(object, values)) {
		result.length = values.length;
		foreach(int i, ref JSONValue aValue; values) {
			if(!getJsonValue(aValue, result[i]))
				return false;
		}
		
		return true;
	}
	return false;
}

/**
 * Gets the value from a JSONValue object.
 */
private template getJsonValue(string type, string json_type, string method) {
	const char[] getJsonValue = `
	bool getJsonValue(JSONValue object, ref ` ~ type ~ ` result) {
		if(object.type == JSON_TYPE.` ~ json_type ~ `) {
			result = cast(`~ type ~`)object.` ~ method ~ `;
			return true;
		}
		return false;
	}`;
}

mixin(getJsonValue!("string"           , "STRING"  , "str"));
mixin(getJsonValue!("int"              , "INTEGER" , "integer"));
mixin(getJsonValue!("uint"             , "UINTEGER", "uinteger"));
mixin(getJsonValue!("long"             , "INTEGER" , "integer"));
mixin(getJsonValue!("ulong"            , "UINTEGER", "uinteger"));
mixin(getJsonValue!("float"            , "FLOAT"   , "floating"));
mixin(getJsonValue!("JSONValue[string]", "OBJECT"  , "object"));
mixin(getJsonValue!("JSONValue[]"      , "ARRAY"   , "array"));

bool getJsonValue(JSONValue object, ref bool result) {
	if(object.type == JSON_TYPE.TRUE)
		result = true;
	else if(object.type == JSON_TYPE.FALSE)
		result = false;
	else return false;
	return true;
}


import dsfml.system.vector2 : Vector2;

/++
 + Gets a Vector2 from an JSONValue that must be an array
 +/
bool getJsonValue(T)(JSONValue object, ref Vector2!T result) {
	T[] coords;
	if(object.getJsonValues(coords)) {
		result = Vector2!T(coords[0], coords[1]);
		return true;
	}
	return false;
}