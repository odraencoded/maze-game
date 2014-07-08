import std.algorithm;

import dsfml.graphics;

import geometry;
import course; 

class Game {
	RenderWindow window;
	bool isRunning;
	
	Course course;
	Stage stage;
	int progress;
}

enum OnOffState {
	Off = 0, On = 1,
	Changed = 2,
	
	TurnedOff = Changed | Off,
	TurnedOn = Changed | On
}

class Stage {
	string title;
	Pusher player;
	Wall[] walls;
	Exit[] exits;
	
	bool isOnExit(Point point) {
		foreach(Exit exit; exits) {
			if(exit.position == point)
				return true;
		}
		return false;
	}
	
	bool canGo(Point position, Side direction, bool skippedGrabbed) {
		position += getOffset(direction);
		
		foreach(Wall wall; walls) {
			if(!(skippedGrabbed && wall.isGrabbed)) {
				if(canFind(wall.blocks, position - wall.position))
					return false;
			}
		}
		return true;
	}
	
	Wall getItem(Point position, Side direction) {
		position += getOffset(direction);
		
		foreach(Wall wall; walls) {
			if(canFind(wall.blocks, position - wall.position))
				return wall;
		}
		return null;
	}
}

class Pusher {
	Point position;
	Side facing = Side.Down;
	
	Wall grabbedItem;
	bool isGrabbing() const { return !(grabbedItem is null); }
	
	void grabItem(Wall item) {
		item.isGrabbed = true;
		grabbedItem = item;
	}
	
	void releaseItem() {
		grabbedItem.isGrabbed = false;
		grabbedItem = null;
	}
}

class Wall {
	Point position;
	Point[] blocks;
	bool isGrabbed;
	bool isFixed;
}

class Exit {
	Point position;
}