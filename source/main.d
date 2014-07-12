import std.stdio;
import std.path;
import core.memory;

import dsfml.graphics;

import game;
import course;
import input;
import screens;
import view;

alias slash = dirSeparator;

enum GO_UP_KEY = Keyboard.Key.I;
enum GO_RIGHT_KEY = Keyboard.Key.L;
enum GO_DOWN_KEY = Keyboard.Key.K;
enum GO_LEFT_KEY = Keyboard.Key.J;
enum GRAB_KEY = Keyboard.Key.D;
enum CAMERA_KEY = Keyboard.Key.W;

enum BACKGROUND_COLOR = Color(64, 64, 64, 255);

enum TEST_PATH = "resources" ~ slash ~ "test";
enum TEST_COURSE_PATH = TEST_PATH ~ slash  ~ "course";

enum DEFAULT_SCALING_MODE = ScalingMode.PixelPerfect;

void main(string[] args) {
	Game game = new Game(GAME_WIDTH, GAME_HEIGHT);
	
	// Open Window
	auto window = game.window = setupWindow();
	game.resizer.scalingMode = DEFAULT_SCALING_MODE;
	game.resizer.checkSize();
	
	// Setup game course
	// If a directory wasn't passed in the arguments, load the test course
	string coursePath = args.length > 1 ? args[1] : TEST_COURSE_PATH;
	auto course = game.course = coursePath.loadCourse();
	game.progress = 0;
	
	// Setup first stage
	game.stage = game.course.buildStage(game.progress);
	
	// Setup input
	InputState input = new InputState;
	input.bind(GO_UP_KEY   , Command.GoUp   );
	input.bind(GO_RIGHT_KEY, Command.GoRight);
	input.bind(GO_DOWN_KEY , Command.GoDown );
	input.bind(GO_LEFT_KEY , Command.GoLeft );
	input.bind(GRAB_KEY    , Command.Grab   );
	input.bind(CAMERA_KEY  , Command.Camera );
	
	// Setup screen
	auto mazeScreen = new MazeScreen(game);
	
	// Main loop
	game.isRunning = true;
	while(true) {
		// Fixed delta
		enum frameDelta = 1.0 / GAME_FRAMERATE;
		
		// Checking events
		input.prepareCycle();
		
		Event event;
		while(window.pollEvent(event)) {
			switch(event.type) {
				// Close window
				case(event.EventType.Closed):
					input.close = true;
					break;
				
				// Resize view
				case(event.EventType.Resized):
					game.resizer.checkSize();
					break;
				
				// Register input
				case(event.EventType.KeyPressed):
					input.pressKey(event.key.code);
					break;
				
				case(event.EventType.KeyReleased):
					input.releaseKey(event.key.code);
					break;
				
				default:
			}
		}
		
		input.finishCycle();
		
		if(input.close)
			window.close();
		
		// Exiting loop
		game.isRunning = game.isRunning && window.isOpen();
		if(!game.isRunning)
			break;
		
		// Logic part of the logic/draw cycle
		mazeScreen.cycle(input, frameDelta);
		
		// Draw stuff
		auto buffer = game.buffer;
		buffer.clear(BACKGROUND_COLOR);
		
		buffer.draw(mazeScreen);
		
		buffer.display();
		
		window.draw(game.resizer);
		window.display();
		
		// Cleaning up the trash
		GC.collect();
	}
}

private RenderWindow setupWindow() {
	auto videoMode = VideoMode(GAME_WIDTH, GAME_HEIGHT);
	auto window = new RenderWindow(videoMode, GAME_TITLE);
	window.setFramerateLimit(GAME_FRAMERATE);
	return window;
}