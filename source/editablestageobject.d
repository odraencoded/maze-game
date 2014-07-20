import std.algorithm;

import geometry;
import mazeeditorscreen;
import stageobject;

public import mazeeditorscreen : EditingContext;

/++
 + Lets objects be edited in the level editor.
 +/
interface EditableStageObject {
	StageObject getOwner();
	
	/++
	 + Grabs an object so it can start dragging.
	 + Returns whether dragging it is allowed.
	 +/
	bool grab(in Point grabPoint);
	
	/++
	 + Drags an object from point from to point to.
	 + Returns whether it has moved and how much it has moved.
	 +/
	bool drag(in Point from, in Point to, out Point offset);
	
	/++
	 + Drops an object. Finishing dragging it.
	 +/
	void drop(in Point dropPoint);
	
	// Fixed-bility stuff
	bool isFixed();
	bool canBeFixed();
	void setFixed(bool fixed);
	
	/++
	 + Removes a block associated to this object.
	 + Returns whether the point was removed and whether the object was
	 + completely erased.
	 +/
	bool eraseBlock(in Point point, out bool destroyed);
	
	/++
	 + Remove this object from the stage.
	 +/
	bool deleteFromStage();
}

/++
 + A simple implementation of EditableStageObject.
 +/
class SimpleEditableStageObject : EditableStageObject {
	SimpleStageObject owner;
	EditingContext context;
	
	this(EditingContext context, SimpleStageObject owner) {
		this.owner = owner;
		this.context = context;
	}
	
	bool isFixed() { return !owner.grabbable; }
	bool canBeFixed() { return false; }
	void setFixed(bool fixed) { owner.grabbable = !fixed; }
	
	bool eraseBlock(in Point point, out bool destroyed) {
		if(point == owner.position) {
			destroyed = deleteFromStage();
			return destroyed;
		} else {
			return false;
		}
	}
	
	bool grab(in Point grabPoint) { return true; }
	
	bool dragCollisionFilter(StageObject object) {
		return object.isObstacle && !(object is owner);
	}
	
	bool drag(in Point from, in Point to, out Point offset) {
		if(owner.isObstacle) {
			return dragObstacle(from, to, offset, &dragCollisionFilter);
		} else {
			offset = to - from;
			owner.position += offset;
			return true;
		}
	}
	
	bool dragObstacle(
		in Point from, in Point to, out Point offset,
		bool delegate(StageObject) collisionFilter
	) {
		// Doesn't move if this object collides with another object.
		// If it does collide, try moving on the horizontal axis,
		// then on the vertical axis, then give up and go eat ice cream.
		immutable auto optimalTarget = owner.position + to - from;
		auto possibleTargets = [optimalTarget];
		if(optimalTarget.x != owner.position.x)
			possibleTargets ~= Point(optimalTarget.x, owner.position.y);
		if(optimalTarget.y != owner.position.y)
			possibleTargets ~= Point(owner.position.x, optimalTarget.y);
		
		auto ownerBlocks = owner.getBlocks();
		foreach(Point targetPosition; possibleTargets) {
			if(!context.stage.collidesWithAny(
				ownerBlocks,
				targetPosition,
				collisionFilter,
			)) {
				offset = targetPosition - owner.position;
				owner.position = targetPosition;
				return true;
			}
		}
		
		return false;
	}
	
	void drop(in Point dropPoint) { }
	
	SimpleStageObject getOwner() {
		return owner;
	}
	
	bool deleteFromStage() {
		return context.stage.remove(owner);
	}
}

/++
 + Editable implementation for pushers
 +/
class PusherEditable : SimpleEditableStageObject {
	Pusher pusherOwner;
	
	this(EditingContext context, Pusher owner) {
		super(context, owner);
		this.pusherOwner = owner;
	}
	
	override bool drag(in Point from, in Point to, out Point offset) {
		bool dragged = super.drag(from, to, offset);		
		
		if(dragged) {
			pusherOwner.facing.faceTowards(offset);
		} else {
			pusherOwner.facing.faceTowards(to - from);
		}
		
		return dragged;
	}
}
 
 
/++
 + Editable implementation for Walls
 +/
class WallEditable : SimpleEditableStageObject {
	Wall wallOwner;
	
	this(EditingContext context, Wall owner) {
		super(context, owner);
		this.wallOwner = owner;
	}
	
	override bool canBeFixed() { return true; }
	
	override bool deleteFromStage() {
		if(super.deleteFromStage()) {
			// Update renderer cache
			context.stageRenderer.updateCachedWalls();
			return true;
		} else {
			return false;
		}
	}
	
	override bool dragCollisionFilter(StageObject object) {
		return (
			// Can't pass through obstacle
			object.isObstacle &&
			// Except when its over itself
			!(object is owner) &&
			// Can overlap with another wall, but only if both are alike
			!(
				canFind(context.stage.walls, object) &&
				object.isGrabbable == owner.isGrabbable
			)
		);
	}
	
	override void drop(in Point dropPoint) {
		// Merge with overlapping walls on drop
		if(mergeOverlapping()) {
			context.stageRenderer.updateCachedWalls();
		}
	}
	
	override bool eraseBlock(in Point block, out bool destroyed) {
		// Convert block to local
		auto localBlock = block - wallOwner.getBlockOffset();
		
		// This returns true if the block was in the associative array btw
		if(wallOwner.blocks.remove(localBlock)) {
			// Invalidate blockPoints
			wallOwner.blockPoints = null;
			
			// Update neighbouring blocks
			auto neighbours = localBlock.getNeighbours(Direction.Cardinal);
			foreach(Side aSide, Point aNeighbour; neighbours) {
				Side* neighbourJoints = aNeighbour in wallOwner.blocks;
				if(neighbourJoints) {
					*neighbourJoints &= ~aSide.getOpposite();
				}
			}
			
			// Check if wall has split into multiple walls
			auto clusters = wallOwner.checkSplit();
			if(clusters.length == 0) {
				destroyed = true;
			} else if(clusters.length > 1) {
				// Keep the first cluster for this wall
				wallOwner.blocks = clusters[0];
				
				// Create new walls for the rest.
				// Fun fact: there can be only up to 3 new walls created by
				// erasing a single block from a wall
				foreach(Side[Point] aCluster; clusters[1..$]) {
					auto newWall = wallOwner.createAlike();
					newWall.blocks = aCluster;
					context.stage.walls ~= newWall;
				}
			}
			
			// Update graphic cache
			context.stageRenderer.updateCachedWalls();
			
			// Successfully removed the block.
			return true;
		} else {
			// Couldn't remove the block, return false because.
			return false;
		}
	}
	
	
	/++
	 + Merges this wall with overlapping walls in the stage and removes them.
	 + Returns whether any merging was done.
	 + This does not update the wall cache.
	 +/
	bool mergeOverlapping() {
		// Get walls overlapping with this object
		auto ownerBlocks = owner.getBlocks();
		auto ownerBlockOffset = owner.getBlockOffset();
		
		auto overlappingWalls = context.stage.getObjects!Wall(
			ownerBlocks,
			ownerBlockOffset,
			o => !(o is owner),
			context.stage.walls,
		);
		
		if(overlappingWalls.length > 0) {
			// Merge overlapping walls
			foreach(Wall anOverlappingWall; overlappingWalls) {
				wallOwner.merge(anOverlappingWall);
				context.stage.remove(anOverlappingWall);
			}
			return true;
		} else {
			// Nothing to merge here.
			return false;
		}
	}
}