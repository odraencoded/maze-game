import std.algorithm;

import dsfml.graphics;

import gamescreen;
import geometry;
import course; 

import view;

enum GAME_WIDTH = 320;
enum GAME_HEIGHT = 180;
enum GAME_FRAMERATE = 30;
enum GAME_TITLE = "Maze Game";
enum GAME_TITLE_SEPARATOR = " - ";

class Game {
	RenderWindow window;
	bool isRunning;
	
	GameScreen currentScreen, nextScreen;
	
	RenderTexture buffer;
	View view;
	immutable Vector2u size;
	
	VideoResizer resizer;
	
	Course course;
	Stage stage;
	int progress;
	
	this(uint width, uint height) {
		size = Vector2u(width, height);
		view = new View(FloatRect(Vector2f(0, 0), size.toVector2f));
		
		resizer = new VideoResizer(this);
	}
}

class Stage {
	string title;
	Pusher player;
	Wall[] walls;
	Exit[] exits;
	
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
				if(canFind(wall.blocks, position - wall.position))
					return false;
			}
		}
		return true;
	}
	
	Wall getItem(Point position, Side direction) pure {
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
	bool isGrabbing() const pure nothrow @safe {
		return !(grabbedItem is null);
	}
	
	void grabItem(Wall item) pure {
		item.isGrabbed = true;
		grabbedItem = item;
	}
	
	void releaseItem() pure {
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