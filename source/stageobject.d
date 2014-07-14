import std.algorithm;
import std.range;

import geometry;
import stage;

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
	
	bool grabbable;
	Pusher grabber;
	
	const(Point[]) getBlocks() { return SINGLE_BLOCK_ARRAY; }
	Point getBlockOffset() { return position; }
	
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
	
	this() {
		grabbable = true;
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
}

class Exit {
	Point position;
}