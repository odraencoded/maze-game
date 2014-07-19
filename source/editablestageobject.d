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
		immutable auto possibleTargets = [
			optimalTarget,
			Point(optimalTarget.x, owner.position.y),
			Point(owner.position.x, optimalTarget.y),
		];
		
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
 + Editable implementation for Walls
 +/
class WallEditable : SimpleEditableStageObject {
	Wall wallOwner;
	
	this(EditingContext context, Wall owner) {
		super(context, owner);
		this.wallOwner = owner;
	}
	
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
			object.isObstacle &&
			!(object is owner) &&
			// This needs improvement
			!canFind(context.stage.walls, object)
		);
	}
	
	override void drop(in Point dropPoint) {
		// Merge with overlapping walls on drop
		if(mergeOverlapping()) {
			context.stageRenderer.updateCachedWalls();
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