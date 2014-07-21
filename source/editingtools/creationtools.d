import assetcodes;
import editingtoolset;
import editorscreen;
import input;
import stageobject;
import tile;

class CreationTool : EditingTool {
	EditorScreen editor;
	this(this T)(EditorScreen screen, TextureMap toolsMap) {
		this.editor = screen;
		this.icon = toolsMap[T.IconAssetCode];
	}
	
	override void cycleActive(in InputState input, in float delta) {
		if(input[SELECT_BUTTON].wasTurnedOn) {
			editor.selectedBlock = editor.gridPointer.current;
			auto newObject = createObject(input, delta);
			
			if(newObject) {
				// Select pusher
				editor.selectedObject = newObject.getEditable(editor.context);
			
				// Switch to selection mode
				editor.toolset.setActive(editor.selectionTool);
			}
		}
	}
	
	abstract StageObject createObject(in InputState input, in float delta);
}

/++
 + Creates a new pusher.
 +/
class PusherTool : CreationTool {
	enum IconAssetCode = ToolsMapKeys.PusherTool;
	
	this(EditorScreen screen, TextureMap toolsMap) {
		super(screen, toolsMap);
	}
	
	override StageObject createObject(in InputState input, in float delta) {
		// Add a new pusher
		auto newPusher = new Pusher();
		newPusher.position = editor.selectedBlock;
		editor.context.stage.pushers ~= newPusher;
		
		return newPusher;
	}
}

/++
 + Creates a new exit.
 +/
class ExitTool : CreationTool {
	enum IconAssetCode = ToolsMapKeys.ExitTool;
	
	this(EditorScreen screen, TextureMap toolsMap) {
		super(screen, toolsMap);
	}
	
	override StageObject createObject(in InputState input, in float delta) {
		auto newExit = new Exit();
		newExit.position = editor.selectedBlock;
		editor.context.stage.exits ~= newExit;
		
		return newExit;
	}
}