public import std.json;

/**
 * JSON utilities because std.json is a pain in the ass to use.
 */


/**
 * Gets object[key] and converts it to the appropriate type of result.
 * Returns true on success.
 */
bool getJsonValue(K, V)(scope JSONValue[K] object, in K key, ref V result) {
	JSONValue* value = key in object;
	if(!(value is null))
		return (*value).getJsonValue(result);
	return false;
}

/**
 * Fills result with data from an array in object[key]
 * Returns true on success.
 */
bool getJsonValues(T, V)(scope JSONValue[T] object, in T key, ref V[] result) {
	JSONValue[] values;
	if(getJsonValue(object, key, values)) {
		result.length = values.length;
		foreach(int i, JSONValue aValue; values) {
			if(!aValue.getJsonValue(result[i]))
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
	bool getJsonValue(scope JSONValue object, ref ` ~ type ~ ` result) {
		if(object.type == JSON_TYPE.` ~ json_type ~ `) {
			result = object.` ~ method ~ `;
			return true;
		}
		return false;
	}`;
}

mixin(getJsonValue!("string"           , "STRING"  , "str"));
mixin(getJsonValue!("long"             , "INTEGER" , "integer"));
mixin(getJsonValue!("ulong"            , "UINTEGER", "uinteger"));
mixin(getJsonValue!("float"            , "FLOAT"   , "floating"));
mixin(getJsonValue!("JSONValue[string]", "OBJECT"  , "object"));
mixin(getJsonValue!("JSONValue[]"      , "ARRAY"   , "array"));

bool getJsonValue(scope JSONValue object, ref bool result) {
	if(object.type == JSON_TYPE.TRUE)
		result = true;
	else if(object.type == JSON_TYPE.TRUE)
		result = false;
	else return false;
	return true;
}