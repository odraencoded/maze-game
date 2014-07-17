import dsfml.graphics;

import game;
import gamescreen;
import mazescreen;
import geometry;
import menu;
import signal;
import stage;
import stageobject;

class MazeEditorScreen : GameScreen {
	Stage stage;
	StageInfo stageMetadata;
	
	Signal!(MazeEditorScreen) onQuit;
	
	this(Game game) {
		super(game);
	}
	
	/++
	 + Sets a stage to be edited in the editor.
	 +/
	void setStage(Stage stage, StageInfo metadata) {
		this.stage = stage;
		this.stageMetadata = metadata;
	}
	
	/++
	 + Starts editing a new clean stage.
	 +/
	void newStage() {
		auto newMetadata = new StageInfo();
		newMetadata.title = "New Stage";
		
		// Create default stage
		auto newStage = new Stage();
		
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
	 + Tests the current stage
	 +/
	void testStage() {
		// Create a copy to test on
		// TODO: Implement cloning
		auto stageCopy = this.stage;
		stageCopy.metadata = &this.stageMetadata;
		
		// Set up the maze screen to play the stage
		auto mazeScreen = new MazeScreen(game);
		mazeScreen.setStage(stageCopy);
		mazeScreen.onQuit ~= { game.nextScreen = this; };
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
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		
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
			mainMenu.items ~= [closeMenuItem, testMenuItem];
		}
		
		// New stage item
		auto newStageMenuItem = menuContext.createMenuItem("New Stage");
		newStageMenuItem.onActivate ~= {
			editorScreen.newStage();
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