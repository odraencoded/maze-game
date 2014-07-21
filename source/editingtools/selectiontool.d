import assetcodes;
import editingtoolset;
import editorscreen;
import geometry;
import input;
import stageobject;
import tile;

class SelectionTool : EditingTool {
	EditorScreen editor;
	this(EditorScreen screen, TextureMap toolsMap) {
		this.editor = screen;
		this.icon = toolsMap[ToolsMapKeys.SelectionTool];
	}
	
	override void cycleActive(in InputState input, in float delta) {
		auto gridPointer = editor.gridPointer;
		auto selectedBlock = editor.selectedBlock;
		
		if(input[SELECT_BUTTON].wasTurnedOn) {
			editor.setSelection(gridPointer.current);
		} else if(input[SELECT_BUTTON].isOn && gridPointer.hasMoved) {
			// Drag selected object
			// Can only drag if there is something selected
			bool dragStuff = !(editor.selectedObject is null);
			// And only when the mouse has moved from a grid block to another
			dragStuff &= gridPointer.hasMoved;
			// And only if that block is not the currently selected block
			dragStuff &= selectedBlock != gridPointer.current;
			
			// Try to start grabbing mode by grabbing the object
			if(dragStuff && !editor.draggingMode) {
				if(editor.selectedObject.grab(selectedBlock)) {
					editor.draggingMode = true;
				} else {
					// Didn't grab, won't drag
					dragStuff = false;
				}
			}
			
			// Finally drag something around
			if(dragStuff) {
				immutable auto fromBlock = selectedBlock;
				immutable auto toBlock = gridPointer.current;
				Point offset;
				editor.selectedObject.drag(fromBlock, toBlock, offset);
				// Move selection
				editor.selectedBlock += offset;
			}
			
			// Set selection to pointer if not dragging
			if(editor.draggingMode == false) {
				editor.setSelection(gridPointer.current);
			}
		} else if(input[SELECT_BUTTON].wasTurnedOn) {
			if(editor.selectedObject)
				editor.selectedObject.drop(selectedBlock);
			
			editor.draggingMode = false;
		}
	}
}