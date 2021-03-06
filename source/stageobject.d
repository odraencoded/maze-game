import std.algorithm;
import std.conv;
import std.range;

import assetcodes;
import editablestageobject;
import game;
import geometry;
import json;
import stage;
import tile;

/++
 + Base class for objects in a stage.
 +/
interface StageObject {
	/++
	 + Serializes this object into a JSON value
	 +/
	JSONValue serialize() const;
	
	/++
	 + Creates an EditableStageObject for this object.
	 +/
	EditableStageObject getEditable(EditingContext context);
	
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
	
	SimpleEditableStageObject getEditable(EditingContext context) {
		return new SimpleEditableStageObject(context, this);
	}
	
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
	
	bool isPlayer = false;
	StageObject grabbedObject;
	Exit exit;
	
	this() {
		grabbable = true;
		obstacle = true;
	}
	
	override PusherEditable getEditable(EditingContext context) {
		return new PusherEditable(context, this);
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
	
	JSONValue serialize() const {
		JSONValue data = JSONValue(new JSONValue[2]);
		
		data[0] = [position.x, position.y];
		data[1] = facing;
		
		return data;
	}
	
	static Pusher load(JSONValue json) {
		auto result = new Pusher();
		
		JSONValue[] someData;
		json.getJsonValue(someData);
		int facing;
		
		getJsonValue(someData[0], result.position);
		getJsonValue(someData[1], facing);
		
		result.facing = facing.to!Side;
		
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
			import std.array;
			blockPoints = blocks.byKey.array;
		}
		return blockPoints;
	}
	
	JSONValue serialize() const {
		JSONValue data = JSONValue(new JSONValue[3]);
		
		data[0] = [position.x, position.y];
		data[1] = grabbable;
		
		// Serialize blocks
		JSONValue[] serializedBlocks;
		foreach(Point block, Side joints; blocks) {
			JSONValue serializedPoint = [block.x, block.y];
			JSONValue serializedJoints = joints;
			serializedBlocks ~= JSONValue([serializedPoint, serializedJoints]);
		}
		data[2] = serializedBlocks;
		
		return data;
	}
	
	static Wall load(JSONValue json) {
		auto result = new Wall();
		
		JSONValue[] someData;
		json.getJsonValue(someData);
		
		getJsonValue(someData[0], result.position);
		getJsonValue(someData[1], result.grabbable);
		
		JSONValue[] serializedBlocks;
		someData[2].getJsonValue(serializedBlocks);
		
		foreach(JSONValue aSerializedBlock; serializedBlocks) {
			Point block;
			int joints;
			getJsonValue(aSerializedBlock[0], block);
			getJsonValue(aSerializedBlock[1], joints);
			
			result.blocks[block] = cast(Side)joints;
		}
		
		return result;
	}
	
	override WallEditable getEditable(EditingContext context) {
		return new WallEditable(context, this);
	}
	
	/++
	 + Removes all blocks from this wall
	 +/
	void destroyBlocks() {
		blocks.clear();
		blockPoints = null;
	}
	
	/++
	 + Adds a block to the wall attaching the surrounding blocks to it
	 +/
	void glueBlock(in Point point) {
		import utility;
		
		// Make sure blocks[point] exists.
		auto newBlockSides = point in blocks;
		if(newBlockSides is null) {
			blocks[point] = Side.None;
			newBlockSides = &blocks[point];
		}
		
		// Search around point for this wall's blocks
		foreach(Side aSide; Side.All.getFlags()) {
			auto offset = aSide.getOffset();
			auto otherBlockSides = (point + offset) in blocks;
			if(otherBlockSides) {
				// Add aSide to this block and
				// its opposite to the other block
				*newBlockSides |= aSide;
				*otherBlockSides |= aSide.getOpposite();
			}
		}
		
		// Invalidate blockPoints
		blockPoints = null;
	}
	
	/++
	 + Add blocks to this wall.
	 +/
	void addBlocks(
		Side[Point] newBlocks, in Point newBlocksOffset = Point(0, 0)
	) {
		if(blocks.length == 0) {
			position = newBlocksOffset;
			blocks = newBlocks;
		} else {
			immutable auto offset = this.getBlockOffset();
			foreach(Point block, Side joints; newBlocks) {
				blocks[block + newBlocksOffset - offset] |= joints;
			}
		}
		
		// Invalidate blockPoints
		blockPoints = null;
	}
	
	/++
	 + Adds blocks from another wall into this one.
	 +/
	void merge(Wall other) {
		addBlocks(other.blocks.dup, other.position);
	}
	
	
	/++
	 + Checks whether this wall blocks have been split, forming multiple
	 + disconnected clusters.
	 + Returns said clusters.
	 +/
	Side[Point][] checkSplit() {
		import std.algorithm;
		
		bool[Point] checkedBlocks;
		Side[Point][] clusters;
		
		foreach(Point p; blocks.byKey) {
			// Skip checked blocks
			if(checkedBlocks.get(p, false))
				continue;
			
			Side[Point] connectedBlocks;
			Point[] heads = [p];
			checkedBlocks[p] = true;
			
			while(heads.length > 0) {
				Point[] newHeads;
				
				foreach(Point aHead; heads) {
					connectedBlocks[aHead] = blocks[aHead];
					
					auto neighbours = aHead.getNeighbours(Direction.Cardinal);
					foreach(Point aNeighbour; neighbours.byValue) {
						// Skip checked blocks
						if(checkedBlocks.get(aNeighbour, false))
							continue;
						
						// Skip if neighbour is not in this wall's blocks
						if(aNeighbour !in blocks)
							continue;
						
						newHeads ~= aNeighbour;
						checkedBlocks[aNeighbour] = true;
					}
				}
				heads = newHeads;
			}
			
			clusters ~= connectedBlocks;
		}
		
		return clusters;
	}
	
	/++
	 + Returns a new wall without blocks but with properties like this one.
	 +/
	Wall createAlike() {
		auto newWall = new Wall();
		newWall.position = this.position;
		newWall.grabbable = this.grabbable;
		return newWall;
	}
	
	VertexCache createSpriteCache(in TextureMap wallMap) {
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

class Exit : SimpleStageObject {
	this() {
		grabbable = false;
		obstacle = false;
	}
	
	JSONValue serialize() const {
		return JSONValue([position.x, position.y]);
	}
	
	static Exit load(JSONValue someData) {
		auto result = new Exit();
		
		someData.getJsonValue(result.position);
		
		return result;
	}
}

