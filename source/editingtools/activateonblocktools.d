import assetcodes;
import editingtoolset;
import editorscreen;
import input;
import tile;

class ActivateOnBlockTool : EditingTool {
	EditorScreen editor;
	this(this T)(EditorScreen screen, TextureMap toolsMap) {
		this.editor = screen;
		this.icon = toolsMap[T.IconAssetCode];
	}
	
	override void cycleActive(in InputState input, in float delta) {
		if(editor.activateOnBlock) {
			editor.setSelection(editor.gridPointer.current);
			useTool();
		}
	}
	
	override void activate() {
		import std.stdio;
		if(this.isActive) {
			useTool();
		}
	}
	
	abstract bool useTool();
}

/++
 + Erases the selected block.
 +/
class EraserTool : ActivateOnBlockTool {
	enum IconAssetCode = ToolsMapKeys.EraserTool;
	
	this(EditorScreen screen, TextureMap toolsMap) {
		super(screen, toolsMap);
	}
	
	override bool useTool() {
		auto selectedObject = editor.selectedObject;
		if(selectedObject) {
			bool destroyed;
			if(selectedObject.eraseBlock(editor.selectedBlock, destroyed)) {
				editor.selectedObject = null;
				return true;
			}
		}
		return false;
	}
}

/++
 + Removes the selected object.
 +/
class TrashTool : ActivateOnBlockTool {
	enum IconAssetCode = ToolsMapKeys.TrashTool;
	
	this(EditorScreen screen, TextureMap toolsMap) {
		super(screen, toolsMap);
	}
	
	override bool useTool() {
		if(editor.selectedObject) {
			return editor.trash(editor.selectedObject);
		} else {
			return false;
		}
	}
}

/++
 + Glues the selected object, e.g. makes walls ungrabbable
 +/
class GlueTool : ActivateOnBlockTool {
	enum IconAssetCode = ToolsMapKeys.GlueTool;
	
	this(EditorScreen screen, TextureMap toolsMap) {
		super(screen, toolsMap);
	}
	
	override bool useTool() {
		auto selectedObject = editor.selectedObject;
		if(selectedObject && selectedObject.canBeFixed) {
			selectedObject.setFixed(!selectedObject.isFixed());
			return true;
		} else {
			return false;
		}
	}
}