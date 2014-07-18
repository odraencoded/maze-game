import std.algorithm;
import std.range;

import course;
import game;
import geometry;
import json;
import stageobject;

private enum JSON_PUSHERS_ARRAY_KEY = "pushers";
private enum JSON_WALLS_ARRAY_KEY = "walls";
private enum JSON_EXITS_ARRAY_KEY = "exits";

class Stage {
	const(StageInfo)* metadata;
	
	Pusher[] pushers;
	Wall[] walls;
	Exit[] exits;
	
	auto getObjects() {
		return chain(pushers, walls, exits);
	}
	
	Exit getExit(in Point point) pure {
		foreach(Exit exit; exits) {
			if(exit.position == point) {
				return exit;
			}
		}
		return null;
	}
	
	/++
	 + Returns obstacles between position and
	 + the point at direction of position.
	 +/
	StageObject[]
	getObstacles(in Point position, in Side direction = Side.None) {
		immutable auto destination = position + direction.getOffset();
		return getObjects(destination, o => o.isObstacle);
	}
	
	StageObject[]
	getObjects(
		in Point position, bool delegate(StageObject) objectFilter = null
	) {
		bool positionFilter(StageObject anObject) {
			if(objectFilter is null || objectFilter(anObject)) {
				immutable auto offset = anObject.getBlockOffset();
				return canFind(anObject.getBlocks(), position - offset);
			} else {
				return false;
			}
		}
		
		import std.array : array;
		import std.conv : to;
		
		auto objects = getObjects();
		return filter!(positionFilter)(objects).array.to!(StageObject[]);
	}
	
	StageObject[]
	getObjects(bool delegate(StageObject) filter) {
		StageObject[] result;
		auto objects = getObjects();
		
		foreach(StageObject anObject; objects) {
			if(filter && !filter(anObject))
				continue;
			
			result ~= anObject;
		}
		return result;
	}
	
	Wall getItem(Point position, Side direction) {
		position += getOffset(direction);
		
		foreach(Wall wall; walls) {
			if(canFind(wall.getBlocks(), position - wall.getBlockOffset()))
				return wall;
		}
		return null;
	}
	
	/++
	 + Returns a stage exactly like this one.
	 +/
	Stage clone() {
		// Most half-assed approach to the problem that still works.
		auto result = loadStage(this.serialize());
		result.metadata = this.metadata;
		return result;
	}
	
	/++
	 + Serializes the stage into a JSON object 
	 +/
	JSONValue* serialize() const {
		// Serializing pushers
		JSONValue[] serializedPushers;
		foreach(const Pusher aPusher; pushers) {
			serializedPushers ~= aPusher.serialize();
		}
		
		// Serializing walls
		JSONValue[] serializedWalls;
		foreach(const Wall aWall; walls) {
			serializedWalls ~= aWall.serialize();
		}
		
		// Serializing exits
		JSONValue[] serializedExits;
		foreach(const Exit anExit; exits) {
			serializedExits ~= anExit.serialize();
		}
		
		// Putting everything together
		JSONValue[string] stageObjects;
		stageObjects[JSON_PUSHERS_ARRAY_KEY] = JSONValue(serializedPushers);
		stageObjects[JSON_WALLS_ARRAY_KEY] = JSONValue(serializedWalls);
		stageObjects[JSON_EXITS_ARRAY_KEY] = JSONValue(serializedExits);
		
		return new JSONValue(stageObjects);
	}
}

class StageInfo {
	string title;
}

/++
 + Builds a stage out of a JSON node
 +/
Stage loadStage(JSONValue* json) {
	Stage result = new Stage();
	
	JSONValue[string] root;
	if(!getJsonValue(*json, root))
		throw new Exception("Not a JSON object.");
	
	// Load pushers
	JSONValue[] pushersData;
	if(root.getJsonValue(JSON_PUSHERS_ARRAY_KEY, pushersData)) {
		result.pushers.length = pushersData.length;
		foreach(int i, ref JSONValue someData; pushersData) {
			result.pushers[i] = Pusher.load(someData);
		}
	}
	
	// Load walls
	JSONValue[] wallsData;
	if(root.getJsonValue(JSON_WALLS_ARRAY_KEY, wallsData)) {
		result.walls.length = wallsData.length;
		foreach(int i, ref JSONValue someData; wallsData) {
			result.walls[i] = Wall.load(someData);
		}
	}
	
	// Load exits
	JSONValue[] exitsData;
	if(root.getJsonValue(JSON_EXITS_ARRAY_KEY, exitsData)) {
		result.exits.length = exitsData.length;
		foreach(int i, ref JSONValue someData; exitsData) {
			result.exits[i] = Exit.load(someData);
		}
	}
	
	return result;
}