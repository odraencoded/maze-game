import std.algorithm;

import course;
import game;
import geometry;

class Stage {
	const StageInfo metadata;
	
	Pusher player;
	Wall[] walls;
	Exit[] exits;
	
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
	
	bool canGo(Point position, Side direction, bool skippedGrabbed) pure {
		position += getOffset(direction);
		
		foreach(Wall wall; walls) {
			if(!(skippedGrabbed && wall.isGrabbed)) {
				if((position - wall.position) in wall.blocks)
					return false;
			}
		}
		return true;
	}
	
	Wall getItem(Point position, Side direction) pure {
		position += getOffset(direction);
		
		foreach(Wall wall; walls) {
			if((position - wall.position) in wall.blocks)
				return wall;
		}
		return null;
	}
}

class StageInfo {
	string title;
}