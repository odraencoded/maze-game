import std.json;
import std.path : slash = dirSeparator;

import dsfml.graphics;

import anchoring;
import game;
import gamescreen;
import mazescreen;
import geometry;
import menu;
import signal;
import stage;
import stageobject;
import stagerenderer;
import tile;
import utility : OnOffState;

enum EDITOR_DIRECTORY = "editor" ~ slash;

enum SELECT_BUTTON = Mouse.Button.Left;
enum DRAG_VIEW_BUTTON = Mouse.Button.Right;

class MazeEditorScreen : GameScreen {
	Stage stage;
	StageInfo stageMetadata;
	
	Signal!(MazeEditorScreen) onQuit;
	StageRenderer stageRenderer;
	
	EditingToolSet toolset;
	EditingToolSet.Anchor toolsetAnchor;
	
	EditingTool selectionTool;
	
	Point selectedBlock;
	MovingPoint gridPointer;
	EditableStageObject selectedObject;
	
	TileSprite cursorSprite;
	Point panning;
	
	Backdrop tiledBlueprintBackground;
	
	this(Game game) {
		super(game);
		auto gameAssets = game.assets;
		
		toolset = new EditingToolSet(gameAssets);
		
		auto toolsMap = gameAssets.maps[Asset.ToolsMap];
		selectionTool = new EditingTool();
		selectionTool.icon = toolsMap[ToolsMapKeys.SelectionTool];
		
		toolset.tools ~= selectionTool;
		
		toolset.activeTool = selectionTool;
		
		toolsetAnchor = toolset.createAnchor();
		toolsetAnchor.side = Side.TopAndRight;
		toolsetAnchor.margin = Point(8, 8);
		
		stageRenderer = new StageRenderer(gameAssets);
		
		// Create cursor sprite
		cursorSprite = new TileSprite();
		cursorSprite.texture = &gameAssets.textures[Asset.SymbolTexture];
		
		auto symbolMap = gameAssets.maps[Asset.SymbolMap];
		cursorSprite.piece = symbolMap[SymbolMapKeys.SquareCursor];
		
		auto tiledBlueprintTexture = &gameAssets.textures[Asset.BlueprintBG];
		tiledBlueprintBackground = new Backdrop(tiledBlueprintTexture);
	}
	
	/++
	 + Sets a stage to be edited in the editor.
	 +/
	void setStage(Stage newStage, StageInfo newMetadata) {
		if(isActiveScreen)
			game.subtitle = newMetadata.title;
		
		stage = newStage;
		stageMetadata = newMetadata;
		stage.metadata = &stageMetadata;
		
		stageRenderer.setStage(stage);
	}
	
	/++
	 + Starts editing a new clean stage.
	 +/
	void setNewStage() {
		auto newMetadata = new StageInfo();
		newMetadata.title = "New Stage";
		
		// Create default stage
		auto newStage = new Stage();
		newStage.metadata = &newMetadata;
		
		// Add a default pusher
		auto defaultPusher = new Pusher();
		defaultPusher.position = Point(1, 1);
		defaultPusher.facing = Side.Down;
		newStage.pushers ~= defaultPusher;
		
		// Add a default exit
		auto defaultExit = new Exit();
		defaultExit.position = Point(5, 5);
		newStage.exits ~= defaultExit;
		
		// Add default frame
		auto defaultFrame = new Wall();
		foreach(int bx; 0..7) {
			defaultFrame.glueBlock(Point(bx, 0));
			defaultFrame.glueBlock(Point(bx, 6));
		}
		foreach(int by; 1..6) {
			defaultFrame.glueBlock(Point(0, by));
			defaultFrame.glueBlock(Point(6, by));
		}
		defaultFrame.grabbable = false;
		newStage.walls ~= defaultFrame;
		
		setStage(newStage, newMetadata);
	}
	
	/++
	 + Saves the stage.
	 +/
	void saveStage() {
		import std.file;
		
		auto stageRoot = stage.serialize();
		auto fileData = stageRoot.toJSON();
		
		mkdirRecurse(EDITOR_DIRECTORY);
		write(EDITOR_DIRECTORY ~ "stage.maze", fileData);
	}
	
	/++
	 + Tests the current stage
	 +/
	void testStage() {
		// Create a copy to test on
		auto stageCopy = stage.clone();
		
		// Set up the maze screen to play the stage
		auto mazeScreen = new MazeScreen(game);
		mazeScreen.setStage(stageCopy);
		mazeScreen.onQuit ~= { game.nextScreen = this; };
		mazeScreen.onRestart ~= { mazeScreen.setStage(this.stage.clone()); };
		game.nextScreen = mazeScreen;
	}
	
	override void appear() {
		// If no stage is loaded in the editor, load the editor settings
		// screen instead
		if(stage is null)
			game.nextScreen = new MazeEditorSettingsScreen(game, this);
		else
			game.subtitle = stageMetadata.title;
	}
	
	override void cycle(in InputState input, in float delta) {
		bool openSettings = false;
		openSettings |= input.wasKeyTurnedOn(SystemKey.Escape);
		if(openSettings) {
			game.nextScreen = new MazeEditorSettingsScreen(game, this);
			return;
		}
		
		// Drag the view while the view dragging mouse button is being held.
		// == On means it must have been TurnedOn before this cycle, so
		// it's the button has been held for at least two cycles
		if(input[DRAG_VIEW_BUTTON] == OnOffState.On) {
			panning -= input.pointer.movement;
		}
		
		// Convert mouse pointer to view coordinates
		immutable auto viewPointer = input.pointer.current + panning;
		gridPointer.move(viewPointer.getGridPoint(BLOCK_SIZE));
		
		// Updating selected block & object
		if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
			selectedBlock = gridPointer.current;
			auto objects = stage.getObjects(selectedBlock);
			if(objects.length > 0) {
				selectedObject = objects[0].getEditable();
			} else {
				selectedObject = null;
			}
		} else if(input.isButtonOn(SELECT_BUTTON)) {
			// Drag selected object
			if(selectedObject) {
				immutable auto targetBlock = selectedBlock + gridPointer.movement;
				selectedObject.drag(selectedBlock, targetBlock);
				selectedBlock = targetBlock;
			}
		}
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		// Set view
		auto viewRect = FloatRect(panning.toVector2f, renderTarget.view.size);
		renderTarget.view = new View(viewRect);
		
		// Draw background
		renderTarget.draw(tiledBlueprintBackground, states);
		
		// Draw stage
		renderTarget.draw(stageRenderer);
		
		// This cursor sprite looks exceptionally bad,
		// but it shows where the cursor is, so it will stay for a while
		cursorSprite.position = selectedBlock * BLOCK_SIZE;
		renderTarget.draw(cursorSprite);
		
		// Reset view
		renderTarget.view = game.view;
		
		auto toolsetStates = RenderStates();
		renderTarget.draw(toolsetAnchor);
	}
}

/++
 + A set of tools.
 +/
class EditingToolSet : DisplayObject!int {// : DisplayObject(int) {
	enum TOOL_WIDTH = BLOCK_SIZE;
	enum TOOL_HEIGHT = BLOCK_SIZE;
	
	GameAssets assets;
	
	EditingTool[] tools;
	EditingTool activeTool;
	VertexCache backgroundCache, iconCache;
	
	uint width = 1;
	
	this(GameAssets assets) {
		this.assets = assets;
	}
	
	void updateCache() {
		// Cache background
		enum OUTLINE_COLOR = Color(0, 0, 0);
		enum FACE_COLOR = Color(231, 220, 193);
		
		auto boxSize = getBottomRight();
		
		auto outlineRect = FloatRect(-1, -1, boxSize.x + 2, boxSize.y + 2);
		auto outlineVertices = outlineRect.toVertexArray();
		outlineVertices.dye(OUTLINE_COLOR);
		
		auto faceRect = IntRect(0, 0, boxSize.x, boxSize.y);
		auto faceVertices = faceRect.toVertexArray();
		faceVertices.dye(FACE_COLOR);
		
		backgroundCache = new VertexCache();
		backgroundCache.add(outlineVertices);
		backgroundCache.add(faceVertices);
		
		// Cache icons
		iconCache = new VertexCache();
		iconCache.texture = &assets.textures[Asset.ToolsTexture];
		foreach(int i, ref EditingTool tool; tools) {
			iconCache.add(tool.icon.vertices, Point(0, i * TOOL_HEIGHT));
		}
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		if(backgroundCache is null)
			updateCache();
		
		renderTarget.draw(backgroundCache, states);
		renderTarget.draw(iconCache, states);
	}
	
	// Anchorable implementation
	Point getTopLeft() {
		return Point(0, 0);
	}
	
	Point getBottomRight() {
		Point size;
		size.x = width * TOOL_WIDTH;
		size.y = TOOL_HEIGHT * (tools.length / width);
		
		// Rounding up. Too lazy to convert to float, get std.math, etc.
		if(tools.length % width > 0)
			size.y += TOOL_HEIGHT;
		
		return size;
	}
}

class EditingTool {
	const(Tile)* icon;
}

class MazeEditorSettingsScreen : GameScreen {
	MenuContext menuContext;
	MazeEditorScreen editorScreen;
	
	this(Game game, MazeEditorScreen screen) {
		super(game);
		
		// Create the menu
		editorScreen = screen;
		menuContext = new MenuContext(game.assets);
		
		auto mainMenu = new Menu();
		
		if(!(editorScreen.stage is null)) {
			// Close settings
			auto closeSettings = { game.nextScreen = editorScreen; };
			auto closeMenuItem = menuContext.createMenuItem("Close");
			closeMenuItem.onActivate ~= closeSettings;
			mainMenu.onCancel ~= closeSettings;
			
			// Test stage
			auto testMenuItem = menuContext.createMenuItem("Test Stage");
			testMenuItem.onActivate ~= { editorScreen.testStage(); };
			
			// Save stage
			auto saveMenuItem = menuContext.createMenuItem("Save Stage");
			saveMenuItem.onActivate ~= { editorScreen.saveStage(); };
			
			mainMenu.items ~= [closeMenuItem, testMenuItem, saveMenuItem];
		}
		
		// New stage item
		auto newStageMenuItem = menuContext.createMenuItem("New Stage");
		newStageMenuItem.onActivate ~= {
			editorScreen.setNewStage();
			game.nextScreen = editorScreen;
		};
		mainMenu.items ~= newStageMenuItem;
		
		// Quit item
		auto quitMenuItem = menuContext.createMenuItem("Quit");
		quitMenuItem.onActivate ~= { editorScreen.onQuit(editorScreen); };
		mainMenu.items ~= [null, quitMenuItem];
		
		menuContext.currentMenu = mainMenu;
	}
	
	override void cycle(in InputState input, in float frameDelta) {
		menuContext.cycle(input, frameDelta);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		// Draw background
		editorScreen.draw(renderTarget, states);
		
		// Reset view
		renderTarget.view = game.view;
		
		// Draw curtain
		enum CURTAIN_COLOR = Color(0, 0, 0, 160);
		
		auto gameSize = game.view.size;
		auto curtain = new RectangleShape(gameSize);
		curtain.fillColor(CURTAIN_COLOR);
		
		renderTarget.draw(curtain);
		
		// Draw menu
		renderTarget.draw(menuContext);
	}
}