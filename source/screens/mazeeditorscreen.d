import std.json;
import std.path : slash = dirSeparator;

import dsfml.graphics;

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

enum EDITOR_DIRECTORY = "editor" ~ slash;

class MazeEditorScreen : GameScreen {
	Stage stage;
	StageInfo stageMetadata;
	
	Signal!(MazeEditorScreen) onQuit;
	StageRenderer stageRenderer;
	
	Point cursor;
	TileSprite cursorSprite;
	
	this(Game game) {
		super(game);
		
		auto assets = game.assets;
		
		stageRenderer = new StageRenderer(assets);
		
		// Create cursor sprite
		cursorSprite = new TileSprite();
		cursorSprite.texture = &assets.textures[Asset.SymbolTexture];
		
		auto symbolMap = assets.maps[Asset.SymbolMap];
		cursorSprite.piece = &symbolMap[SymbolMapKeys.SquareCursor];
	}
	
	/++
	 + Sets a stage to be edited in the editor.
	 +/
	void setStage(Stage newStage, StageInfo newMetadata) {
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
	}
	
	override void cycle(in InputState input, in float delta) {
		bool openSettings = false;
		openSettings |= input.wasKeyTurnedOn(SystemKey.Escape);
		if(openSettings) {
			game.nextScreen = new MazeEditorSettingsScreen(game, this);
			return;
		}
		
		cursor = input.pointer / BLOCK_SIZE;
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		renderTarget.draw(stageRenderer);
		
		// This cursor sprite looks exceptionally bad,
		// but it shows where the cursor is, so it will stay for a while
		cursorSprite.position = cursor * BLOCK_SIZE;
		renderTarget.draw(cursorSprite);
	}
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