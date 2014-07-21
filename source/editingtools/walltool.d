import assetcodes;
import editingtoolset;
import editorscreen;
import geometry;
import input;
import stageobject;
import tile;

class WallTool : EditingTool {
	EditorScreen editor;
	this(EditorScreen screen, TextureMap toolsMap) {
		this.editor = screen;
		this.icon = toolsMap[ToolsMapKeys.WallTool];
	}
	
	override void cycleActive(in InputState input, in float delta) {
		auto gridPointer = editor.gridPointer;
		auto selectedBlock = editor.selectedBlock;
		auto context = editor.context;
		
		Wall* wallInConstruction = &editor.wallInConstruction;
		
		if(input[SELECT_BUTTON].wasTurnedOn) {
			// Update selection
			editor.setSelection(gridPointer.current);
			
			// Start constructing a new wall
			*wallInConstruction = new Wall();
			wallInConstruction.glueBlock(gridPointer.current);
			
			// Propagate whether the wall is fixed from the
			// current selected object (which is under the cursor)
			auto selectedObject = editor.selectedObject;
			if(selectedObject) {
				auto wallEditable = wallInConstruction.getEditable(context);
				if(selectedObject.canBeFixed && wallEditable.canBeFixed) {
					wallEditable.setFixed(selectedObject.isFixed);
				}
			}
			
			editor.stageRenderer.updateConstructionCache();
		} else if(input[SELECT_BUTTON].isOn) {
			// Add blocks to the wall
			if(*wallInConstruction && gridPointer.hasMoved) {
				import std.algorithm;
				
				if(!*wallInConstruction)
					return;
				
				// Reset new wall blocks
				wallInConstruction.destroyBlocks();
				
				// Create wall blocks in shape of a rectangle from
				// the start of the drag until the current point
				auto gridDragStart = editor.gridDragStart;
				auto gridLastDraggedBlock = editor.gridLastDraggedBlock;
				int left = min(gridDragStart.x, gridLastDraggedBlock.x);
				int top = min(gridDragStart.y, gridLastDraggedBlock.y);
				int right = max(gridDragStart.x, gridLastDraggedBlock.x);
				int bottom = max(gridDragStart.y, gridLastDraggedBlock.y);
				
				foreach(int x; left..right + 1) {
					foreach(int y; top..bottom + 1) {
						wallInConstruction.glueBlock(Point(x, y));
					}
				}
				
				editor.stageRenderer.updateConstructionCache();
			}
		} else if(input[SELECT_BUTTON].wasTurnedOff) {
			if(!*wallInConstruction)
				return;
			
			// Finish constructing wall
			context.stage.walls ~= *wallInConstruction;
			
			// Tell the wall to merge with overlapping walls
			wallInConstruction.getEditable(context).mergeOverlapping();
			
			// Select new wall
			auto wallBlocks = wallInConstruction.getBlocks();
			auto wallBlockOffset = wallInConstruction.getBlockOffset();
			// Update selected block only if it's not already at the new wall
			import std.algorithm : canFind;
			if(!canFind(wallBlocks, selectedBlock - wallBlockOffset)) {
				editor.selectedBlock = editor.gridLastDraggedBlock;
			}
			editor.selectedObject = wallInConstruction.getEditable(context);
			*wallInConstruction = null;
			
			// Update wall cache
			editor.stageRenderer.updateCachedWalls();
			editor.stageRenderer.updateConstructionCache();
		}
	}
}