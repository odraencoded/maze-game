import std.algorithm;
import std.range;

import course;
import game;
import geometry;
import stageobject;

class Stage {
	const StageInfo metadata;
	
	Pusher[] pushers;
	Wall[] walls;
	Exit[] exits;
	
	auto getObjects() {
		return chain(pushers, walls);
	}
	
	this(in StageInfo metadata) {
		this.metadata = metadata;
	}
	
	bool isOnExit(Point point) pure {
		foreach(Exit exit; exits) {
			if(exit.position == point)
				return true;
		}
		return false;
	}
	
	/++
	 + Returns obstacles between position and
	 + the point at direction of position.
	 +/
	StageObject[] getObstacles(in Point position, in Side direction) {
		immutable auto destination = position + direction.getOffset();
		
		StageObject[] result;
		auto objects = chain(pushers, walls);
		
		foreach(StageObject anObject; objects) {
			immutable auto offset = anObject.getBlockOffset();
			if(canFind(anObject.getBlocks(), destination - offset)) {
				
				result ~= anObject;
			}
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
}

class StageInfo {
	string title;
}