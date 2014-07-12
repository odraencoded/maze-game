import std.algorithm;

import dsfml.graphics;

import geometry;
import course; 

import view;

class Game {
	RenderWindow window;
	bool isRunning;
	
	RenderTexture buffer;
	View view;
	immutable Vector2u size;
	
	VideoResizer resizer;
	
	Course course;
	Stage stage;
	int progress;
	
	this(uint width, uint height) {
		size = Vector2u(width, height);
		view = new View();
		
		resizer = new VideoResizer(this);
	}
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