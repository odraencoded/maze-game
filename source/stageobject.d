import std.algorithm;
import std.range;

import game;
import geometry;
import stage;
import tile;

/++
 + Base class for objects in a stage.
 +/
interface StageObject {
	/++
	 + Returns the points where this object is.
	 +/
	const(Point[]) getBlocks();
	
	/++
	 + A value to be added getBlocks() to convert the points' coordinates from
	 + local to global.
	 +/
	Point getBlockOffset();
	
	/++
	 + Whether this object gets in the way of others.
	 +/
	bool isObstacle() @property;
	
	/++
	 + Whether the object can be grabbed right now.
	 +/
	bool isGrabbable() @property;
	bool isGrabbed() @property;
	Pusher getGrabber();
	void setGrabber(Pusher grabber);
	
	StageObject[] getConnections();
	
	/++
	 + Whether this object can move towards direction.
	 +/
	bool canMoveAlone(Stage stage, in Side direction);
	
	/++
	 + Moves this object toward direction.
	 +/
	void moveAlone(Stage stage, in Side direction);
	
	/++
	 + Checks whether this object and all objects connected to it can move
	 + towards direction
	 +/
	final bool canMove(Stage stage, in Side direction) {
		StageObject[] connections = this.getAllConnections();
		foreach(StageObject aConnection; connections) {
			if(!aConnection.canMoveAlone(stage, direction)) {
				return false;
			}
		}
		
		return canMoveAlone(stage, direction);
	}
	
	/++
	 + Move this object and all objects connected to it towards direction.
	 +/
	final void move(Stage stage, in Side direction) {
		StageObject[] connections = this.getAllConnections();
		foreach(StageObject aConnection; connections) {
			aConnection.moveAlone(stage, direction);
		}
		moveAlone(stage, direction);
	}
	
	/++
	 + Returns all objects connected to this object except this object.
	 +/
	final StageObject[] getAllConnections() {
		return getAllConnected([this]);
	}
	
	/++
	 + Returns all objects connected to sources except themselves.
	 +/
	static StageObject[] getAllConnected(StageObject[] sources) {
		StageObject[] result;
		
		StageObject[] connections = sources;
		while(connections.length > 0) {
			StageObject[] newConnections;
			
			foreach(StageObject aConnection; connections) {
				auto moreConnections = aConnection.getConnections();
				foreach(StageObject anotherConnection; moreConnections) {
					if(!canFind(chain(result, sources), anotherConnection)) {
						newConnections ~= anotherConnection;
						result ~= anotherConnection;
					}
				}
			}
			
			connections = newConnections;
		}
		return result;
	}
}

/++
 + A simple implementation of StageObject.
 +/
abstract class SimpleStageObject : StageObject {
	Point position;
	
	bool grabbable, obstacle;
	Pusher grabber;
	
	const(Point[]) getBlocks() { return SINGLE_BLOCK_ARRAY; }
	Point getBlockOffset() { return position; }
	
	bool isObstacle() { return obstacle; }
	
	bool isGrabbable() @property { return grabbable; }
	bool isGrabbed() @property { return !(grabber is null); }
	Pusher getGrabber() { return grabber; }
	void setGrabber(Pusher grabber) { this.grabber = grabber; }
	
	StageObject[] getConnections() {
		if(this.isGrabbed)
			return [this.grabber];
		else return new StageObject[0];
	}
	
	bool canMoveAlone(Stage stage, in Side direction) {
		StageObject[] passthrough = [this];
		passthrough ~= this.getAllConnections();
		return canMoveAlone(stage, direction, passthrough);
	}
	
	bool canMoveAlone(Stage stage, in Side direction,
	                  in StageObject[] passthrough) {
		foreach(Point block; this.getBlocks()) {
			block += this.getBlockOffset();
			
			StageObject[] obstacles = stage.getObstacles(block, direction);
			foreach(StageObject anObstacle; obstacles) {
				if(canFind(passthrough, anObstacle))
					continue;
				
				return false;
			}
		}
		
		return true;
	}
	
	void moveAlone(Stage stage, in Side direction) {
		position += direction.getOffset();
	}
}

static immutable auto SINGLE_BLOCK_ARRAY = [Point(0, 0)];

class Pusher : SimpleStageObject  {
	Side facing = Side.Down;
	
	StageObject grabbedObject;
	Exit exit;
	
	this() {
		grabbable = true;
		obstacle = true;
	}
	
	bool isGrabbing() @property { return !(grabbedObject is null); }
	
	void grabObject(Stage stage) {
		StageObject[] objects = stage.getObstacles(position, facing);
		if(objects.length > 0) {
			auto anObject = objects[0];
			if(anObject && anObject.isGrabbable && !anObject.isGrabbed)
				grabObject(stage, anObject);
		}
	}
	
	void grabObject(Stage stage, StageObject object) {
		object.setGrabber(this);
		grabbedObject = object;
	}
	
	void releaseObject() {
		grabbedObject.setGrabber(null);
		grabbedObject = null;
	}
	
	override StageObject[] getConnections() {
		StageObject[] result;
		
		if(this.grabbedObject)
			result ~= this.grabbedObject;
		
		if(this.isGrabbed)
			result ~= this.grabber;
		
		return result;
	}
}

class Wall : SimpleStageObject {
	Side[Point] blocks;
	Point[] blockPoints = null;
	
	this() {
		grabbable = true;
		obstacle = true;
	}
	
	override const(Point[]) getBlocks() {
		if(blockPoints is null) {
			blockPoints = new Point[blocks.length];
			int i = 0;
			foreach(Point aPoint; blocks.byKey) {
				blockPoints[i] = aPoint;
				i++;
			}
		}
		return blockPoints;
	}
	
	VertexCache createSpriteCache(TextureMap wallMap) {
		import dsfml.system.vector2;
		
		enum CORNER_SIZE = BLOCK_SIZE / 2;
		
		// Caching the tiles used in a wall
		auto wallCache = new VertexCache();
		foreach(Point block,  Side joints; blocks) {
			immutable auto blockPosition = block * BLOCK_SIZE;
			
			// Cache fill tile
			Vector2i tilePosition = blockPosition;
			auto tileVertices = &wallMap[WallMapKeys.Fill].vertices;
			wallCache.add(*tileVertices, tilePosition);
			
			// Iterate through the four corners
			foreach(int i; 0..4) {
				auto mapKey = (joints & CORNER_FILTERS[i]) in CORNER_MAP[i];
				if(!mapKey)
					continue;
				
				// Cache corner tile
				tilePosition = blockPosition + CORNER_OFFSETS[i] * CORNER_SIZE;
				tileVertices = &wallMap[*mapKey].vertices;
				wallCache.add(*tileVertices, tilePosition);
			}
		}
		
		return wallCache;
	}
	
	// Corner constants, used to cache the wall
	private static immutable auto CORNER_FILTERS = [
		Side.Top    | Side.Left ,
		Side.Top    | Side.Right,
		Side.Bottom | Side.Right,
		Side.Bottom | Side.Left ,
	];
	
	private static immutable auto CORNER_OFFSETS = [
		Point(0, 0), Point(1, 0), Point(1, 1), Point(0, 1)
	];
	
	private static immutable int[int][4] CORNER_MAP;
	private static immutable int[int] TOP_LEFT_CORNER_MAP;
	private static immutable int[int] TOP_RIGHT_CORNER_MAP;
	private static immutable int[int] BOTTOM_RIGHT_CORNER_MAP;
	private static immutable int[int] BOTTOM_LEFT_CORNER_MAP;
	
	
	static this() {
		import std.stdio;
		writeln(CORNER_MAP[0]);
		writeln(WallMapKeys.TopLeftSide);
		
		TOP_LEFT_CORNER_MAP[Side.None  ] = WallMapKeys.TopLeftSide;
		TOP_LEFT_CORNER_MAP[Side.Top   ] = WallMapKeys.LeftSide;
		TOP_LEFT_CORNER_MAP[Side.Left  ] = WallMapKeys.TopSide;
		
		TOP_RIGHT_CORNER_MAP[Side.None  ] = WallMapKeys.TopRightSide;
		TOP_RIGHT_CORNER_MAP[Side.Top   ] = WallMapKeys.RightSide;
		TOP_RIGHT_CORNER_MAP[Side.Right ] = WallMapKeys.TopSide;
		
		BOTTOM_RIGHT_CORNER_MAP[Side.None  ] = WallMapKeys.BottomRightSide;
		BOTTOM_RIGHT_CORNER_MAP[Side.Bottom] = WallMapKeys.RightSide;
		BOTTOM_RIGHT_CORNER_MAP[Side.Right ] = WallMapKeys.BottomSide;
		
		BOTTOM_LEFT_CORNER_MAP[Side.None  ] = WallMapKeys.BottomLeftSide;
		BOTTOM_LEFT_CORNER_MAP[Side.Bottom] = WallMapKeys.LeftSide;
		BOTTOM_LEFT_CORNER_MAP[Side.Left  ] = WallMapKeys.BottomSide;
		
		CORNER_MAP[0] = TOP_LEFT_CORNER_MAP;
		CORNER_MAP[1] = TOP_RIGHT_CORNER_MAP;
		CORNER_MAP[2] = BOTTOM_RIGHT_CORNER_MAP;
		CORNER_MAP[3] = BOTTOM_LEFT_CORNER_MAP;
	}
}

class Exit {
	Point position;
}

