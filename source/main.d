import std.path : slash = dirSeparator;

import dsfml.graphics.color : Color;
import scaling : ScalingMode;

import game;

enum GAME_WIDTH = 320;
enum GAME_HEIGHT = 180;
enum GAME_FRAMERATE = 30;
enum GAME_TITLE = "Maze Game";

enum BACKGROUND_COLOR = Color(32, 32, 32, 255);
enum DEFAULT_SCALING_MODE = ScalingMode.PixelPerfect;

void main(string[] args) {
	auto mazeGame = new Game(GAME_TITLE, GAME_WIDTH, GAME_HEIGHT);
	
	// Open Window
	auto window = mazeGame.window = setupWindow();
	mazeGame.resizer.scalingMode = DEFAULT_SCALING_MODE;
	mazeGame.resizer.checkSize();
	
	loadAssets(mazeGame);
	
	// Setup input
	auto input = setupInput();
	
	// Setup screen
	// If a directory is passed in the arguments we load it directly
	import menuscreen : MenuScreen;
	auto goToMenu = { mazeGame.nextScreen = new MenuScreen(mazeGame); };
	if(args.length > 1) {
		import coursecontext;
		import course : loadCourse;
		Game realGame = mazeGame;
		auto course = loadCourse(args[1]);
		auto context = new CourseContext(realGame , course);
		
		context.startPlaying();
		
		auto openMenuScreen = goToMenu;
		context.onGameQuit ~= openMenuScreen;
		context.onCourseComplete ~= openMenuScreen;
	} else {
		goToMenu();
	}
	
	// Switch screens
	mazeGame.currentScreen = mazeGame.nextScreen;
	mazeGame.nextScreen = null;
	
	// Main loop
	mazeGame.isRunning = true;
	while(true) {
		// Fixed delta
		enum frameDelta = 1.0 / GAME_FRAMERATE;
		
		// Checking events
		input.prepareCycle();
		
		import dsfml.window.event : Event;
		Event event;
		while(window.pollEvent(event)) {
			switch(event.type) {
				// Close window
				case(Event.EventType.Closed):
					input.close = true;
					break;
				
				// Resize view
				case(Event.EventType.Resized):
					mazeGame.resizer.checkSize();
					break;
				
				// Register input
				case(Event.EventType.KeyPressed):
					input.pressKey(event.key.code);
					break;
				
				case(Event.EventType.KeyReleased):
					input.releaseKey(event.key.code);
					break;
				
				case(Event.EventType.LostFocus):
					input.lostFocus = true;
					break;
				
				default:
			}
		}
		
		input.finishCycle();
		
		if(input.close)
			window.close();
		
		// Logic part of the logic/draw cycle
		mazeGame.currentScreen.cycle(input, frameDelta);
		
		// Exiting loop
		mazeGame.isRunning = mazeGame.isRunning && window.isOpen();
		if(!mazeGame.isRunning)
			break;
		
		// Drawing part
		auto buffer = mazeGame.buffer;
		buffer.clear(BACKGROUND_COLOR);
		
		// Update view
		buffer.view = mazeGame.view;
		
		// Draw screen
		buffer.draw(mazeGame.currentScreen);
		
		// Flip
		buffer.display();
		
		// Not even bothering clearing the window since buffer should cover it
		window.draw(mazeGame.resizer);
		window.display();
		
		// Changing screens
		if(mazeGame.nextScreen) {
			mazeGame.currentScreen = mazeGame.nextScreen;
			mazeGame.nextScreen = null;
			
			// Reset input so that it's not carried on to the next screen
			input.reset();
		}
		
		// Cleaning up the trash
		import core.memory : GC;
		GC.collect();
	}
}

private auto setupWindow() {
	import dsfml.graphics : VideoMode, RenderWindow;
	
	auto videoMode = VideoMode(GAME_WIDTH, GAME_HEIGHT);
	auto window = new RenderWindow(videoMode, GAME_TITLE);
	window.setFramerateLimit(GAME_FRAMERATE);
	return window;
}

private auto setupInput() {
	import input;
	import dsfml.window : Keyboard;
	
	auto result = new InputState();
	
	// TODO: Replace this by something that loads bindings from a file.
	result.bind(Keyboard.Key.I, Command.GoUp         );
	result.bind(Keyboard.Key.L, Command.GoRight      );
	result.bind(Keyboard.Key.K, Command.GoDown       );
	result.bind(Keyboard.Key.J, Command.GoLeft       );
	result.bind(Keyboard.Key.Q, Command.CyclePrevious);
	result.bind(Keyboard.Key.E, Command.CycleNext    );
	result.bind(Keyboard.Key.D, Command.Grab         );
	result.bind(Keyboard.Key.W, Command.Camera       );
	result.bind(Keyboard.Key.R, Command.Restart      );
	
	return result;
}

private void loadAssets(Game mazeGame) {
	import dsfml.graphics;
	
	enum MENU_FONT_FILENAME = "assets" ~ slash ~ "text" ~ slash ~ "Munro.ttf";
	
	auto assets = mazeGame.assets;
	
	auto menuFont = assets.menuFont = new Font();
	menuFont.loadFromFile(MENU_FONT_FILENAME);
	
	// Selector sprite
	{
		VertexArray selector = new VertexArray(PrimitiveType.Triangles, 3);
		selector[0].position = Vector2f(2, 2);
		selector[1].position = Vector2f(2, 14);
		selector[2].position = Vector2f(12, 8);
		for(int i=0; i<3; i++) selector[i].color = Color.White;
		
		assets.sprites[Asset.MenuSelector] = selector;
	}
}