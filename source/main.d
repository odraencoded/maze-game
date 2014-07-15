import std.stdio;
import std.path;
import core.memory;

import dsfml.graphics;

import game;
import course;
import input;
import screens;
import view;
import coursecontext;

alias slash = dirSeparator;

enum GO_UP_KEY          = Keyboard.Key.I;
enum GO_RIGHT_KEY       = Keyboard.Key.L;
enum GO_DOWN_KEY        = Keyboard.Key.K;
enum GO_LEFT_KEY        = Keyboard.Key.J;
enum CYCLE_PREIVOUS_KEY = Keyboard.Key.Q;
enum CYCLE_NEXT_KEY     = Keyboard.Key.E;
enum GRAB_KEY           = Keyboard.Key.D;
enum CAMERA_KEY         = Keyboard.Key.W;

enum BACKGROUND_COLOR = Color(32, 32, 32, 255);

enum DEFAULT_SCALING_MODE = ScalingMode.PixelPerfect;

void main(string[] args) {
	Game game = new Game(GAME_TITLE, GAME_WIDTH, GAME_HEIGHT);
	
	// Open Window
	auto window = game.window = setupWindow();
	game.resizer.scalingMode = DEFAULT_SCALING_MODE;
	game.resizer.checkSize();
	
	// Setup input
	InputState input = new InputState;
	input.bind(GO_UP_KEY         , Command.GoUp          );
	input.bind(GO_RIGHT_KEY      , Command.GoRight       );
	input.bind(GO_DOWN_KEY       , Command.GoDown        );
	input.bind(GO_LEFT_KEY       , Command.GoLeft        );
	input.bind(CYCLE_PREIVOUS_KEY, Command.CyclePrevious );
	input.bind(CYCLE_NEXT_KEY    , Command.CycleNext     );
	input.bind(GRAB_KEY          , Command.Grab          );
	input.bind(CAMERA_KEY        , Command.Camera        );
	
	// Setup screen
	// If a directory is passed in the arguments we load it directly
	if(args.length > 1) {
		auto course = loadCourse(args[1]);
		auto context = new CourseContext(game, course);
		
		context.startPlaying();
		
		context.onCourseComplete = (CourseContext context) {
			game.nextScreen = new MenuScreen(game);
		};
	} else {
		game.nextScreen = new MenuScreen(game);
	}
	
	// Switch screens
	game.currentScreen = game.nextScreen;
	game.nextScreen = null;
	
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
		
		// Logic part of the logic/draw cycle
		game.currentScreen.cycle(input, frameDelta);
		
		// Exiting loop
		game.isRunning = game.isRunning && window.isOpen();
		if(!game.isRunning)
			break;
		
		// Drawing part
		auto buffer = game.buffer;
		buffer.clear(BACKGROUND_COLOR);
		
		// Update view
		buffer.view = game.view;
		
		// Draw screen
		buffer.draw(game.currentScreen);
		
		// Flip
		buffer.display();
		
		// Not even bothering clearing the window since buffer should cover it
		window.draw(game.resizer);
		window.display();
		
		// Changing screens
		if(game.nextScreen) {
			game.currentScreen = game.nextScreen;
			game.nextScreen = null;
			
			// Reset view
			game.view.reset(FloatRect(Vector2f(0, 0), game.view.size));
			
			// Reset input so that it's not carried on to the next screen
			input.reset();
		}
		
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