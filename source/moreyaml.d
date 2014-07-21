static import yaml;

V tryGet(V, K)(yaml.Node node, in K key, lazy V fallback) {
	auto valuePointer = key in node;
	if(valuePointer is null) {
		return fallback;
	} else {
		if(valuePointer.isType!V) {
			return valuePointer.as!V;
		} else {
			return fallback;
		}
	}
}

bool tryGet(V)(yaml.Node node, ref V result) {
	if(node.isType!V) {
		result = node.as!V;
		return true;
	} else {
		return false;
	}
}