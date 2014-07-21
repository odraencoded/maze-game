import std.json;
import std.path : slash = dirSeparator;

import dsfml.graphics;

import anchoring;
import assetcodes;
import editablestageobject;
import editingtools;
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
enum MAZE_EXTENSION = ".maze";

enum SELECT_BUTTON = Mouse.Button.Left;
enum DRAG_VIEW_BUTTON = Mouse.Button.Right;

enum NEW_STAGE_TITLE = "New Stage";
enum FALLBACK_STAGE_TITLE = "Untitled";
enum FALLBACK_STAGE_FILENAME = EDITOR_DIRECTORY ~ slash ~ "untitled.maze";

class EditorScreen : GameScreen {
	EditingContext context;
	
	string stageFilename;
	
	Signal!(EditorScreen) onQuit;
	EditorStageRenderer stageRenderer;
	
	EditingToolSet toolset;
	EditingToolSet.Anchor toolsetAnchor;
	
	EditingTool
		selectionTool, eraserTool, trashTool,
		wallTool, glueTool,
		pusherTool, exitTool;
	
	Point selectedBlock, gridDragStart, gridLastDraggedBlock;
	bool activateOnBlock, draggingMode;
	MovingPoint gridPointer;
	EditableStageObject selectedObject;
	Wall wallInConstruction;
	
	TileSprite cursorSprite;
	Point panning;
	
	Backdrop tiledBlueprintBackground;
	
	this(Game game) {
		super(game);
		auto gameAssets = game.assets;
		
		toolset = new EditingToolSet(gameAssets);
		
		// Create tools
		auto toolsMap = gameAssets.maps[Asset.ToolsMap];
		selectionTool = new SelectionTool(this, toolsMap);
		eraserTool = new EraserTool(this, toolsMap);
		trashTool = new TrashTool(this, toolsMap);
		wallTool = new WallTool(this, toolsMap);
		glueTool = new GlueTool(this, toolsMap);
		pusherTool = new PusherTool(this, toolsMap);
		exitTool = new ExitTool(this, toolsMap);
		
		toolset.tools = [
			selectionTool, eraserTool, trashTool,
			wallTool, glueTool,
			pusherTool, exitTool
		];
		
		toolset.setActive(selectionTool);
		
		toolsetAnchor = toolset.createAnchor();
		toolsetAnchor.side = Side.TopAndRight;
		toolsetAnchor.margin = Point(8, 8);
		
		stageRenderer = new EditorStageRenderer(gameAssets, this);
		
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
	void setStage(Stage newStage, StageInfo newMetadata, string filename) {
		stageFilename = filename;
		
		context = new EditingContext();
		context.editorScreen = this;
		context.stage = newStage;
		context.stageMetadata = newMetadata;
		context.stageRenderer = stageRenderer;
		
		newStage.metadata = &context.stageMetadata;
		
		stageRenderer.setStage(newStage);
		
		if(isActiveScreen) {
			refreshSubtitle();
		}
		
		panning = Point(0, 0);
		selectedBlock = Point(0, 0);
		selectedObject = null;
		wallInConstruction = null;
		draggingMode = false;
	}
	
	/++
	 + Starts editing a new clean stage.
	 +/
	void setNewStage() {
		auto newMetadata = new StageInfo();
		newMetadata.title = NEW_STAGE_TITLE;
		
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
		
		setStage(newStage, newMetadata, null);
	}
	
	/++
	 + Saves the stage.
	 +/
	void saveStage(string filename = null) {
		if(context) {
			if(filename is null) {
				if(stageFilename is null) {
					filename = FALLBACK_STAGE_FILENAME;
				} else {
					filename = stageFilename;
				}
			}
			
			context.stage.saveToDisk(filename);
			stageFilename = filename;
		}
	}
	
	/++
	 + Loads a stage from a file
	 +/
	void loadStage(string filename) {
		StageInfo newMetadata;
		Stage newStage;
		
		newStage = Stage.FromDisk(filename);
		
		// TODO: Add a way to load metadata
		if(newMetadata is null) {
			newMetadata = new StageInfo();
			newMetadata.title = FALLBACK_STAGE_TITLE;
		}
		
		setStage(newStage, newMetadata, filename);
	}
	
	
	/++
	 + Tests the current stage
	 +/
	void testStage() {
		// Create a copy to test on
		auto stageCopy = context.stage.clone();
		
		// Set up the maze screen to play the stage
		auto mazeScreen = new MazeScreen(game);
		mazeScreen.setStage(stageCopy);
		mazeScreen.onQuit ~= { game.nextScreen = this; };
		mazeScreen.onRestart ~= {
			auto stageCopy = context.stage.clone();
			mazeScreen.setStage(stageCopy);
		};
		game.nextScreen = mazeScreen;
	}
	
	override void appear() {
		refreshSubtitle();
		
		// If no context is loaded in the editor, load the editor settings
		// screen instead
		if(context is null)
			game.nextScreen = new EditorSettingsScreen(game, this);
	}
	
	override void cycle(in InputState input, in float delta) {
		bool openSettings = false;
		openSettings |= input.wasKeyTurnedOn(SystemKey.Escape);
		if(openSettings) {
			game.nextScreen = new EditorSettingsScreen(game, this);
			return;
		}
		
		// Whether mouse events go to stage editing
		// e.g. no clicks on buttons or toolbars
		bool hoveringStage = true;
		
		immutable auto pointer = input.pointer.current;
		immutable auto gameSize = game.view.size.toVector2!int;
		auto toolsetPoint = toolsetAnchor.convertPoint(pointer, gameSize);
		auto highlightTool = toolset.getToolAt(toolsetPoint);
		toolset.setHightlight(highlightTool);
		
		hoveringStage = !toolset.isUnderPoint(toolsetPoint);
		
		if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
			// Sets the active tool on click
			if(highlightTool) {
				toolset.setActive(highlightTool);
			}
		}
		
		if(hoveringStage) {
			checkStageInput(input, delta);
		}
	}
	
	void checkStageInput(in InputState input, in float delta) {
		// Drag the view while the view dragging mouse button is being held.
		// == On means it must have been TurnedOn before this cycle, so
		// it's the button has been held for at least two cycles
		if(input[DRAG_VIEW_BUTTON] == OnOffState.On) {
			panning -= input.pointer.movement;
		}
		
		// Set up this well used variable
		activateOnBlock = false;
		if(input.wasButtonTurnedOn(SELECT_BUTTON))
			activateOnBlock = true;
		else if(input.isButtonOn(SELECT_BUTTON) && gridPointer.hasMoved)
			activateOnBlock =true;
		
		// Convert mouse pointer to view coordinates
		immutable auto viewPointer = input.pointer.current + panning;
		gridPointer.move(viewPointer.getGridPoint(BLOCK_SIZE));
		
		// Set where the drag started
		if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
			gridDragStart = gridPointer.current;
		} else if(input.isButtonOn(SELECT_BUTTON)) {
			gridLastDraggedBlock = gridPointer.current;
		}
		
		// Updating selected block & object
		toolset.cycle(input, delta);
		
		if(input.wasKeyTurnedOn(Keyboard.Key.Delete)) {
			if(selectedObject)
				trash(selectedObject);
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
	
	/++
	 + Sets selectedBlock and selectedObject to a given point
	 +/
	void setSelection(Point point) {
		selectedBlock = point;
		auto objects = context.stage.getObjects(selectedBlock);
		if(objects.length > 0) {
			selectedObject = objects[0].getEditable(context);
		} else {
			selectedObject = null;
		}
	}
	
	/++
	 + Removes an object from the stage.
	 + Returns whether it was removed.
	 +/
	bool trash(EditableStageObject trashedObject) {
		// Check whether the trashed object is also the selected object
		bool removingSelection = true;
		if(selectedObject) {
			if(selectedObject.getOwner() == trashedObject.getOwner())
				removingSelection = true;
		}
		
		auto trashed = trashedObject.deleteFromStage();
		
		// Clear selection if the selection was deleted
		if(removingSelection && trashed)
			selectedObject = null;
			
		return trashed;
	}
	
	void refreshSubtitle() {
		import std.path;
		if(context) {
			if(stageFilename is null) {
				game.subtitle = "New Maze";
			} else {
				auto baseDirectory = EDITOR_DIRECTORY.absolutePath;
				game.subtitle = relativePath(stageFilename, baseDirectory);
			}
		} else { 
			game.subtitle = "Editor";
		}
	}
}

class EditorStageRenderer : StageRenderer {
	import mazescreen;
	
	EditorScreen screen;
	VertexCache[Wall] constructionCache;
	
	this(GameAssets assets, EditorScreen screen) {
		super(assets);
		this.screen = screen;
	}
	
	void updateConstructionCache() {
		if(screen.wallInConstruction) {
			updateCachedWalls([screen.wallInConstruction], constructionCache);
		} else {
			constructionCache.clear();
		}
	}
	
	override protected void renderWalls(RenderTarget target) {
		super.renderWalls(target);
		if(screen.wallInConstruction) {
			super.renderWalls(constructionCache, target);
		}
	}
}

class EditingContext {
	Stage stage;
	StageInfo stageMetadata;
	EditorScreen editorScreen;
	EditorStageRenderer stageRenderer;
}

class EditorSettingsScreen : GameScreen {
	MenuContext menuContext;
	EditorScreen editorScreen;
	Menu mainMenu;
	
	enum CURTAIN_COLOR = Color(0, 0, 0, 160);
	Backdrop curtain;
	
	this(Game game, EditorScreen screen) {
		super(game);
		
		// Setup curtain
		curtain = new Backdrop(CURTAIN_COLOR);
		
		// Create the menu
		editorScreen = screen;
		menuContext = new MenuContext(game.assets);
		
		mainMenu = new Menu();
		
		// Has an editing context = has a stage loaded
		if(editorScreen.context) {
			// Close settings
			auto editMenuItem = menuContext.createMenuItem("Edit");
			editMenuItem.onActivate ~= &closeSettings;
			mainMenu.onCancel ~= &closeSettings;
			
			// Test stage
			auto testMenuItem = menuContext.createMenuItem("Test Stage");
			testMenuItem.onActivate ~= { editorScreen.testStage(); };
			
			mainMenu.items ~= [editMenuItem, testMenuItem, null];
		}
		
		// New stage item
		auto newStageMenuItem = menuContext.createMenuItem("New Stage");
		newStageMenuItem.onActivate ~= {
			editorScreen.setNewStage();
			closeSettings();
		};
		mainMenu.items ~= newStageMenuItem;
		
		if(editorScreen.context) {
			// Save stage
			auto saveMenuItem = menuContext.createMenuItem("Save Stage");
			saveMenuItem.onActivate ~= &showSaveMenu;
			mainMenu.items ~= saveMenuItem;
		}
		
		// Load stage item
		auto loadStageMenuItem = menuContext.createMenuItem("Load Stage");
		loadStageMenuItem.onActivate ~= &showLoadMenu;
		mainMenu.items ~= loadStageMenuItem;
		
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
		renderTarget.draw(curtain);
		
		// Draw menu
		renderTarget.draw(menuContext);
	}
	
	void showMainMenu() {
		menuContext.selection = 0;
		menuContext.currentMenu = mainMenu;
	}
	
	void showSaveMenu() {
		import std.conv;
		import std.path;
		
		// Get name shown when the screen appears
		string startName;
		if(editorScreen.stageFilename) {
			auto absoluteEditorDirectory = EDITOR_DIRECTORY.absolutePath;
			startName = editorScreen.stageFilename;
			startName = relativePath(startName, absoluteEditorDirectory);
		} else {
			startName = "";
		}
		
		auto saveMenu = new Menu();
		saveMenu.onCancel ~= &showMainMenu;
		
		// Create menu name item
		auto nameTextGraphic = menuContext.createText();
		auto nameMenuItem = new TextEntryMenuItem(
			nameTextGraphic,
			menuContext,
			"Name: ", startName.to!dstring
		);
		
		// Create save menu item
		auto saveMenuItem = menuContext.createMenuItem("Save");
		saveMenuItem.onActivate ~= {
			// Build filename from input
			auto filename = nameMenuItem.typedText.to!string;
			filename = defaultExtension(filename, MAZE_EXTENSION);
			filename = buildNormalizedPath(EDITOR_DIRECTORY, filename);
			auto basename = filename.baseName;
			
			// TODO: some feedback on this would be nice but I already wasted
			// too much time on this stupid level editor
			bool validName = basename.stripExtension.length > 0;
			validName &= isValidFilename(basename);
			validName &= isValidPath(filename);
			if(validName) {
				// TODO: Have this somewhere else maybe
				auto newTitle = basename.stripExtension;
				editorScreen.context.stageMetadata.title = newTitle;
				editorScreen.saveStage(filename);
				closeSettings();
			}
		};
		
		// Create cancel menu item
		auto cancelMenuItem = menuContext.createMenuItem("Cancel");
		cancelMenuItem.onActivate ~= &showMainMenu;
		saveMenu.items = [nameMenuItem, saveMenuItem, null, cancelMenuItem];
		
		// Set current menu
		menuContext.currentMenu = saveMenu;
		
		// Decide where the selector starts based on the name length
		if(startName.length == 0) {
			menuContext.selectedItem = nameMenuItem;
			nameMenuItem.beginTextEntry();
		} else {
			menuContext.selectedItem = saveMenuItem;
		}
	}
	
	void showLoadMenu() {
		import std.file;
		import std.path;
		
		string[] mazeFilepaths;
		
		// Fetch .maze file names
		auto fileList = dirEntries(EDITOR_DIRECTORY, SpanMode.breadth);
		foreach(DirEntry anEntry; fileList) {
			if(anEntry.isFile) {
				auto aFilepath = anEntry.name.absolutePath;
				if(aFilepath.extension == MAZE_EXTENSION) {
					mazeFilepaths ~= aFilepath;
				}
			}
		}
		
		// Create menu
		auto loadMenu = new Menu();
		loadMenu.onCancel ~= &showMainMenu;
		
		// Create menu items
		string[MenuItem] mazeItemsPaths;
		auto loadOneMazeMenuItem = (MenuItem item) {
			auto aPath = mazeItemsPaths[item];
			editorScreen.loadStage(aPath);
			closeSettings();
		};
		
		auto absoluteEditorDirectory = EDITOR_DIRECTORY.absolutePath;
		foreach(string aPath; mazeFilepaths) {
			auto shownName = relativePath(aPath, absoluteEditorDirectory);
			auto mazeMenuItem = menuContext.createMenuItem(shownName);
			mazeItemsPaths[mazeMenuItem] = aPath;
			mazeMenuItem.onActivate ~= loadOneMazeMenuItem;
			loadMenu.items ~= [mazeMenuItem];
		}
		
		// Create cancel menu item
		auto cancelMenuItem = menuContext.createMenuItem("Cancel");
		cancelMenuItem.onActivate ~= &showMainMenu;
		
		if(mazeFilepaths.length > 0)
			loadMenu.items ~= null;
		loadMenu.items ~= cancelMenuItem;
		
		menuContext.selection = 0;
		menuContext.currentMenu = loadMenu;
	}
	
	void closeSettings() {
		game.nextScreen = editorScreen;
	}
}