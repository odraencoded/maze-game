import std.json;
import std.path : slash = dirSeparator;

import dsfml.graphics;

import anchoring;
import assetcodes;
import editablestageobject;
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

class MazeEditorScreen : GameScreen {
	EditingContext context;
	
	string stageFilename;
	
	Signal!(MazeEditorScreen) onQuit;
	MazeEditorStageRenderer stageRenderer;
	
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
		selectionTool = new EditingTool();
		selectionTool.icon = toolsMap[ToolsMapKeys.SelectionTool];
		
		eraserTool = new EditingTool();
		eraserTool.icon = toolsMap[ToolsMapKeys.EraserTool];
		
		trashTool = new EditingTool();
		trashTool.icon = toolsMap[ToolsMapKeys.TrashTool];
		
		wallTool = new EditingTool();
		wallTool.icon = toolsMap[ToolsMapKeys.WallTool];
		
		glueTool = new EditingTool();
		glueTool.icon = toolsMap[ToolsMapKeys.GlueTool];
		
		pusherTool = new EditingTool();
		pusherTool.icon = toolsMap[ToolsMapKeys.PusherTool];
		
		exitTool = new EditingTool();
		exitTool.icon = toolsMap[ToolsMapKeys.ExitTool];
		
		toolset.tools = [
			selectionTool, eraserTool, trashTool,
			wallTool, glueTool,
			pusherTool, exitTool
		];
		
		toolset.activeTool = selectionTool;
		
		toolsetAnchor = toolset.createAnchor();
		toolsetAnchor.side = Side.TopAndRight;
		toolsetAnchor.margin = Point(8, 8);
		
		stageRenderer = new MazeEditorStageRenderer(gameAssets, this);
		
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
		
		Stage.LoadStage(filename, newStage, newMetadata);
		
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
			game.nextScreen = new MazeEditorSettingsScreen(game, this);
	}
	
	override void cycle(in InputState input, in float delta) {
		bool openSettings = false;
		openSettings |= input.wasKeyTurnedOn(SystemKey.Escape);
		if(openSettings) {
			game.nextScreen = new MazeEditorSettingsScreen(game, this);
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
		if(toolset.activeTool == selectionTool) {
			checkSelectionTool(input, delta);
		} else if(toolset.activeTool == trashTool) {
			if(activateOnBlock) {
				setSelection(gridPointer.current);
				trashSelection();
			}
		} else if(toolset.activeTool == glueTool) {
			if(activateOnBlock) {
				// Refresh selection
				setSelection(gridPointer.current);
				
				// Toggle glued/unglued walls
				if(selectedObject && selectedObject.canBeFixed) {
					selectedObject.setFixed(!selectedObject.isFixed());
				}
			}
		} else if(toolset.activeTool == wallTool) {
			checkWallTool(input, delta);
		} else if(toolset.activeTool == eraserTool) {
			if(activateOnBlock) {
				setSelection(gridPointer.current);
				
				if(selectedObject) {
					bool destroyed;
					selectedObject.eraseBlock(selectedBlock, destroyed);
					if(destroyed) {
						selectedObject = null;
					}
				}
			}
		} else if(toolset.activeTool == pusherTool) {
			if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
				// Add a new pusher
				auto newPusher = new Pusher();
				newPusher.position = gridPointer.current;
				context.stage.pushers ~= newPusher;
				
				// Select pusher
				selectedObject = newPusher.getEditable(context);
				selectedBlock = newPusher.position;
				
				// Switch to selection mode
				toolset.setActive(selectionTool);
			}
		}
		else if(toolset.activeTool == exitTool) {
			if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
				// Add a new pusher
				auto newExit = new Exit();
				newExit.position = gridPointer.current;
				context.stage.exits ~= newExit;
				
				// Select pusher
				selectedObject = newExit.getEditable(context);
				selectedBlock = newExit.position;
				
				// Switch to selection mode
				toolset.setActive(selectionTool);
			}
		}
		
		if(input.wasKeyTurnedOn(Keyboard.Key.Delete)) {
			trashSelection();
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
	
	void checkSelectionTool(in InputState input, in float delta) {
		if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
			setSelection(gridPointer.current);
		} else if(input.isButtonOn(SELECT_BUTTON) && gridPointer.hasMoved) {
			// Drag selected object
			// Can only drag if there is something selected
			bool dragStuff = !(selectedObject is null);
			// And only when the mouse has moved from a grid block to another
			dragStuff &= gridPointer.hasMoved;
			// And only if that block is not the currently selected block
			dragStuff &= selectedBlock != gridPointer.current;
			
			// Try to start grabbing mode by grabbing the object
			if(dragStuff && !draggingMode) {
				if(selectedObject.grab(selectedBlock)) {
					draggingMode = true;
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
				selectedObject.drag(fromBlock, toBlock, offset);
				// Move selection
				selectedBlock += offset;
			}
			
			// Set selection to pointer if not dragging
			if(draggingMode == false) {
				setSelection(gridPointer.current);
			}
		} else if(input.wasButtonTurnedOff(SELECT_BUTTON)) {
			if(selectedObject)
				selectedObject.drop(selectedBlock);
			
			draggingMode = false;
		}
	}
	
	void checkWallTool(in InputState input, in float delta) {
		if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
			// Update selection
			setSelection(gridPointer.current);
			
			// Start constructing a new wall
			wallInConstruction = new Wall();
			wallInConstruction.glueBlock(gridPointer.current);
			
			// Propagate whether the wall is fixed from the
			// current selected object (which is under the cursor)
			if(selectedObject) {
				auto wallEditable = wallInConstruction.getEditable(context);
				if(selectedObject.canBeFixed && wallEditable.canBeFixed) {
					wallEditable.setFixed(selectedObject.isFixed);
				}
			}
			
			stageRenderer.updateConstructionCache();
		} else if(input.isButtonOn(SELECT_BUTTON)) {
			// Add blocks to the wall
			if(wallInConstruction && gridPointer.hasMoved) {
				import std.algorithm;
				
				if(!wallInConstruction)
					return;
				
				// Reset new wall blocks
				wallInConstruction.destroyBlocks();
				
				// Create wall blocks in shape of a rectangle from
				// the start of the drag until the current point
				int left = min(gridDragStart.x, gridLastDraggedBlock.x);
				int top = min(gridDragStart.y, gridLastDraggedBlock.y);
				int right = max(gridDragStart.x, gridLastDraggedBlock.x);
				int bottom = max(gridDragStart.y, gridLastDraggedBlock.y);
				
				foreach(int x; left..right + 1) {
					foreach(int y; top..bottom + 1) {
						wallInConstruction.glueBlock(Point(x, y));
					}
				}
				
				stageRenderer.updateConstructionCache();
			}
		} else if(input.wasButtonTurnedOff(SELECT_BUTTON)) {
			if(!wallInConstruction)
				return;
			
			// Finish constructing wall
			context.stage.walls ~= wallInConstruction;
			
			// Tell the wall to merge with overlapping walls
			wallInConstruction.getEditable(context).mergeOverlapping();
			
			// Select new wall
			auto wallBlocks = wallInConstruction.getBlocks();
			auto wallBlockOffset = wallInConstruction.getBlockOffset();
			// Update selected block only if it's not already at the new wall
			import std.algorithm : canFind;
			if(!canFind(wallBlocks, selectedBlock - wallBlockOffset)) {
				selectedBlock = gridLastDraggedBlock;
			}
			selectedObject = wallInConstruction.getEditable(context);
			wallInConstruction = null;
			
			// Update wall cache
			stageRenderer.updateCachedWalls();
			stageRenderer.updateConstructionCache();
		}
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
	 + Removes the currently selected object.
	 + Returns whether it was removed.
	 +/
	bool trashSelection() {
		if(selectedObject && trash(selectedObject)) {
			selectedObject = null;
			return true;
		} else {
			return false;
		}
	}
	
	/++
	 + Removes an object from the stage.
	 + Returns whether it was removed.
	 +/
	bool trash(EditableStageObject trashedObject) {
		return trashedObject.deleteFromStage();
	}
	
	void refreshSubtitle() {
		import std.path;
		if(context) {
			if(stageFilename is null) {
				game.subtitle = "New Maze";
			} else {
				game.subtitle = stageFilename.baseName;
			}
		} else { 
			game.subtitle = "Editor";
		}
	}
}

class MazeEditorStageRenderer : StageRenderer {
	import mazescreen;
	
	MazeEditorScreen screen;
	VertexCache[Wall] constructionCache;
	
	this(GameAssets assets, MazeEditorScreen screen) {
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
	MazeEditorScreen editorScreen;
	MazeEditorStageRenderer stageRenderer;
}

/++
 + A set of tools.
 +/
class EditingToolSet : DisplayObject!int {
	enum TOOL_WIDTH = 16;
	enum TOOL_HEIGHT = 16;
	enum VERTICAL_PADDING = 0;
	enum BORDER_WIDTH = 1;
	
	GameAssets assets;
	
	EditingTool[] tools;
	EditingTool activeTool, highlightTool;
	VertexCache backgroundCache, iconCache, selectionCache;
	VertexCache highlightCache, selectionHighlightCache;
	
	uint width = 1;
	
	this(GameAssets assets) {
		this.assets = assets;
	}
	
	/++
	 + Returns the tool at point p
	 +/
	EditingTool getToolAt(Point p) {
		enum FULL_HEIGHT = TOOL_HEIGHT + VERTICAL_PADDING * 2 + BORDER_WIDTH;
		
		Point boxSize = getBottomRight();
		
		// Check if contained in the active tool sprite
		if(activeTool) {
			auto activeY = selectionCache.position.y;
			if(p.x >= -1 && p.y >= activeY - 1 && p.x < boxSize.x + 1) {
				if(p.y < activeY + TOOL_HEIGHT - BORDER_WIDTH + 1) {
					return activeTool;
				}
			}
		}
		
		// Check if contained in the toolbar
		if(p.x < boxSize.x && p.y < boxSize.y && p.x >= 0 && p.y >= 0) {
			if((p.y % FULL_HEIGHT) < FULL_HEIGHT - BORDER_WIDTH) {
				int highlightIndex = p.y / FULL_HEIGHT;
				return tools[highlightIndex];
			}
		}
		
		// Not found
		return null;
	}
	
	/++
	 + Sets the highlighted tool
	 +/
	void setHightlight(EditingTool tool) {
		highlightTool = tool;
		if(!(highlightTool is null)) {
			import std.algorithm : countUntil;
			int highlightIndex = tools.countUntil(highlightTool);
			highlightCache.position.y = getY(highlightIndex);
			selectionHighlightCache.position.y = highlightCache.position.y;
		}
	}
	
	/++
	 + Sets the highlighted tool
	 +/
	void setActive(EditingTool tool) {
		activeTool = tool;
		if(!(activeTool is null)) {
			import std.algorithm : countUntil;
			int activeIndex = tools.countUntil(activeTool);
			selectionCache.position.y = getY(activeIndex);
			selectionHighlightCache.position.y = selectionCache.position.y;
		}
	}
	
	int getY(int index) const pure {
		int result;
		
		int rowCount = index / width;
		// Rounding up. Too lazy to convert to float, get std.math, etc.
		if(tools.length % width > 0)
			rowCount += 1;
		
		result = TOOL_HEIGHT * rowCount;
		result += VERTICAL_PADDING * rowCount * 2;
		result += BORDER_WIDTH * rowCount;
		
		return result;
	}
	
	void updateCache() {
		// Cache background
		enum OUTLINE_COLOR = Color(0, 0, 0);
		enum FACE_COLOR = Color(190, 180, 160);
		enum SELECTION_FACE_COLOR = Color(231, 220, 193);
		enum BORDER_COLOR = Color(0, 0, 0, 64);
		enum HIGHLIGHT_COLOR = Color(255, 255, 255);
		
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
		
		// Cache selection sprite
		outlineRect = FloatRect(-2, -2, TOOL_WIDTH + 4, TOOL_HEIGHT + 4);
		outlineVertices = outlineRect.toVertexArray();
		outlineVertices.dye(OUTLINE_COLOR);
		
		faceRect = IntRect(-1, -1, TOOL_WIDTH + 2, TOOL_HEIGHT + 2);
		faceVertices = faceRect.toVertexArray();
		faceVertices.dye(SELECTION_FACE_COLOR);
		
		selectionCache = new VertexCache();
		selectionCache.add(outlineVertices);
		selectionCache.add(faceVertices);
		
		// Cache selection highlight sprite
		auto highlightVertices = faceRect.toVertexArray();
		highlightVertices.dye(HIGHLIGHT_COLOR);
		
		selectionHighlightCache = new VertexCache();
		selectionHighlightCache.add(highlightVertices);
		
		// Create highlight sprite
		faceRect = IntRect(0, 0, TOOL_WIDTH, TOOL_HEIGHT);
		highlightVertices = faceRect.toVertexArray();
		highlightVertices.dye(HIGHLIGHT_COLOR);
		
		highlightCache = new VertexCache();
		highlightCache.add(highlightVertices);
		
		// Cache icons, create border vertices
		Vertex[] borderVertices;
		
		iconCache = new VertexCache();
		iconCache.texture = &assets.textures[Asset.ToolsTexture];
		int toolY = -BORDER_WIDTH;
		foreach(int i, ref EditingTool tool; tools) {
			if(i > 0) {
				auto borderRect = IntRect(0, toolY, boxSize.x, BORDER_WIDTH);
				borderVertices ~= borderRect.toVertexArray();
			}
			toolY += BORDER_WIDTH + VERTICAL_PADDING;
			
			if(tool == activeTool)
				selectionCache.position.y = toolY;
			
			iconCache.add(tool.icon.vertices, Point(0, toolY));
			toolY += TOOL_HEIGHT + VERTICAL_PADDING;
		}
		
		borderVertices.dye(BORDER_COLOR);
		backgroundCache.add(borderVertices);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		if(backgroundCache is null)
			updateCache();
		
		// Draw background
		renderTarget.draw(backgroundCache, states);
		
		// Draw highlight sprite
		if(!(highlightTool is null) && !(highlightTool is activeTool)) {
			renderTarget.draw(highlightCache, states);
		}
		
		// Draw selection sprite
		if(!(activeTool is null)) {
			renderTarget.draw(selectionCache, states);
			
			// Draw highlight sprite
			if(highlightTool is activeTool) {
				renderTarget.draw(selectionHighlightCache, states);
			}
		}
		
		// Draw icons on top of everything
		renderTarget.draw(iconCache, states);
	}
	
	// Anchorable implementation
	Point getTopLeft() {
		return Point(0, 0);
	}
	
	Point getBottomRight() {
		Point size;
		size.x = width * TOOL_WIDTH;
		size.y = getY(tools.length) - BORDER_WIDTH;
		
		return size;
	}
	
	bool isUnderPoint(Point p) {
		immutable auto tl = getTopLeft();
		immutable auto br = getBottomRight();
		
		// Check if inside bar
		if(p.x >= tl.x && p.x < br.x && p.y >= tl.y && p.y < br.y)
			return true;
		
		// Check if contained in the active tool sprite
		if(activeTool) {
			auto activeY = selectionCache.position.y;
			if(p.x >= tl.x - 1 && p.y >= activeY - 1 && p.x < br.x + 1) {
				if(p.y < activeY + TOOL_HEIGHT - BORDER_WIDTH + 1) {
					return true;
				}
			}
		}
		
		return false;
	}
}

class EditingTool {
	const(Tile)* icon;
}

class MazeEditorSettingsScreen : GameScreen {
	MenuContext menuContext;
	MazeEditorScreen editorScreen;
	Menu mainMenu;
	
	this(Game game, MazeEditorScreen screen) {
		super(game);
		
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
		enum CURTAIN_COLOR = Color(0, 0, 0, 160);
		
		auto gameSize = game.view.size;
		auto curtain = new RectangleShape(gameSize);
		curtain.fillColor(CURTAIN_COLOR);
		
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
			startName = editorScreen.stageFilename.baseName;
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
			auto inputName = nameMenuItem.typedText.to!string;
			auto basename = defaultExtension(inputName, MAZE_EXTENSION);
			// TODO: some feedback on this would be nice but I already wasted
			// too much time on this stupid level editor
			if(isValidFilename(basename)) {
				auto filename = EDITOR_DIRECTORY ~ basename;
				// TODO: Have this somewhere else maybe
				editorScreen.context.stageMetadata.title = inputName;
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
		auto fileList = dirEntries(EDITOR_DIRECTORY, SpanMode.shallow);
		foreach(DirEntry anEntry; fileList) {
			if(anEntry.isFile) {
				auto aFilepath = anEntry.name;
				if(anEntry.name.extension == MAZE_EXTENSION) {
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
		
		foreach(string aPath; mazeFilepaths) {
			auto mazeMenuItem = menuContext.createMenuItem(aPath.baseName);
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