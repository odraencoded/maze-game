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
	MazeEditorStageRenderer stageRenderer;
	
	EditingToolSet toolset;
	EditingToolSet.Anchor toolsetAnchor;
	
	EditingTool selectionTool, trashTool, wallTool, pusherTool, exitTool;
	
	Point selectedBlock;
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
		
		auto toolsMap = gameAssets.maps[Asset.ToolsMap];
		selectionTool = new EditingTool();
		selectionTool.icon = toolsMap[ToolsMapKeys.SelectionTool];
		
		trashTool = new EditingTool();
		trashTool.icon = toolsMap[ToolsMapKeys.TrashTool];
		
		wallTool = new EditingTool();
		wallTool.icon = toolsMap[ToolsMapKeys.WallTool];
		
		pusherTool = new EditingTool();
		pusherTool.icon = toolsMap[ToolsMapKeys.PusherTool];
		
		exitTool = new EditingTool();
		exitTool.icon = toolsMap[ToolsMapKeys.ExitTool];
		
		toolset.tools = [
			selectionTool, trashTool,
			wallTool, pusherTool, exitTool
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
				// Trash tool can't be active. You click it once
				// and the selection is deleted.
				if(highlightTool == trashTool) {
					trashSelection();
				} else {
					toolset.setActive(highlightTool);
				}
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
		
		// Convert mouse pointer to view coordinates
		immutable auto viewPointer = input.pointer.current + panning;
		gridPointer.move(viewPointer.getGridPoint(BLOCK_SIZE));
		
		// Updating selected block & object
		if(toolset.activeTool == selectionTool) {
			if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
				selectedBlock = gridPointer.current;
				auto objects = stage.getObjects(selectedBlock);
				if(objects.length > 0) {
					selectedObject = objects[0].getEditable(stage);
				} else {
					selectedObject = null;
				}
			} else if(input.isButtonOn(SELECT_BUTTON)) {
				// Drag selected object
				if(selectedObject && gridPointer.hasMoved) {
					auto targetBlock = selectedBlock + gridPointer.movement;
					selectedObject.drag(selectedBlock, targetBlock);
					selectedBlock = targetBlock;
				}
			}
		} else if(toolset.activeTool == wallTool) {
			if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
				// Start constructing a new wall
				wallInConstruction = new Wall();
				wallInConstruction.glueBlock(gridPointer.current);
				stageRenderer.updateConstructionCache();
			} else if(input.isButtonOn(SELECT_BUTTON)) {
				// Add blocks to the wall
				if(wallInConstruction && gridPointer.hasMoved) {
					wallInConstruction.glueBlock(gridPointer.current);
					stageRenderer.updateConstructionCache();
				}
			} else if(input.wasButtonTurnedOff(SELECT_BUTTON)) {
				// Finish constructing wall
				stage.walls ~= wallInConstruction;
				stageRenderer.updateCachedWalls();
				
				wallInConstruction = null;
				stageRenderer.updateConstructionCache();
			}
		} else if(toolset.activeTool == pusherTool) {
			if(input.wasButtonTurnedOn(SELECT_BUTTON)) {
				// Add a new pusher
				auto newPusher = new Pusher();
				newPusher.position = gridPointer.current;
				stage.pushers ~= newPusher;
				
				// Select pusher
				selectedObject = newPusher.getEditable(stage);
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
				stage.exits ~= newExit;
				
				// Select pusher
				selectedObject = newExit.getEditable(stage);
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
	bool trash(EditableStageObject object) {
		int previousWallCount = stage.walls.length;
		if(selectedObject.deleteFromStage()) {
			// Update wall cache if removing the object affected the wall count
			if(stage.walls.length != previousWallCount) {
				stageRenderer.updateCachedWalls();
			}
			return true;
		} else {
			return false;
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

/++
 + A set of tools.
 +/
class EditingToolSet : DisplayObject!int {// : DisplayObject(int) {
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
		enum FACE_COLOR = Color(231, 220, 193);
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
		faceVertices.dye(FACE_COLOR);
		
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