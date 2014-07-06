import std.math;
import std.algorithm;

import dsfml.graphics;

alias Point = Vector2!int;

class Game {
	RenderWindow window;
	bool isRunning;
	
	Stage stage;
}

enum OnOffState {
	Off = 0, On = 1,
	Changed = 2,
	
	TurnedOff = Changed | Off,
	TurnedOn = Changed | On
}

enum Side {
	None        = 0,
	Top         = 1,
	TopRight    = 2,
	Right       = 4,
	BottomRight = 8,
	Bottom      = 16,
	BottomLeft  = 32,
	Left        = 64,
	TopLeft     = 128,
	
	Up = Top,
	Down = Bottom,
	
	Vertical = Top | Bottom,
	Horizontal = Left | Right,
}

class Stage {
	Pusher player;
	Wall[] walls;
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
}

Side getDirection(Point offset) {
	if(offset.x) offset.x /= abs(offset.x);
	if(offset.y) offset.y /= abs(offset.y);
	return directionTable[offset];
}

Point getOffset(Side side) {
	return offsetTable[side];
}

private immutable Side[Point] directionTable;
private immutable Point[Side] offsetTable;

static this() {
	// Initialize direction table
	directionTable[Point( 0,  0)] = Side.None;
	directionTable[Point( 0, -1)] = Side.Top;
	directionTable[Point( 1, -1)] = Side.TopRight;
	directionTable[Point( 1,  0)] = Side.Right;
	directionTable[Point( 1,  1)] = Side.BottomRight;
	directionTable[Point( 0,  1)] = Side.Bottom;
	directionTable[Point(-1,  1)] = Side.BottomLeft;
	directionTable[Point(-1,  0)] = Side.Left;
	directionTable[Point(-1, -1)] = Side.TopLeft;
	
	foreach(Point offset, Side side; directionTable)
		offsetTable[side] = offset;
}