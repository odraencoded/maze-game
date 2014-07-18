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
		
		import dsfml.window: Event, Keyboard, Mouse;
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
					immutable auto keyCode = event.key.code;
					input.pressKey(cast(Keyboard.Key)keyCode);
					break;
				
				case(Event.EventType.KeyReleased):
					immutable auto keyCode = event.key.code;
					input.releaseKey(cast(Keyboard.Key)keyCode);
					break;
				
				case(Event.EventType.MouseButtonPressed):
					immutable auto buttonCode = event.mouseButton.button;
					input.pressButton(cast(Mouse.Button)buttonCode);
					break;
				
				case(Event.EventType.MouseButtonReleased):
					immutable auto buttonCode = event.mouseButton.button;
					input.releaseButton(cast(Mouse.Button)buttonCode);
					break;
				
				case(Event.EventType.LostFocus):
					input.lostFocus = true;
					break;
				
				default:
			}
		}
		
		// Update mouse
		immutable auto windowPointer = Mouse.getPosition(mazeGame.window);
		immutable auto gamePointer = mazeGame.resizer.scalePoint(windowPointer);
		input.pointer.move(gamePointer);
		
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
			mazeGame.currentScreen.disappear();
			
			// In case .disappear() forces the screen to remain the same
			if(mazeGame.nextScreen != mazeGame.currentScreen) {
				import gamescreen : GameScreen;
				GameScreen nextScreen;
				do {
					nextScreen = mazeGame.nextScreen;
					nextScreen.appear();
				} while(nextScreen != mazeGame.nextScreen);
				
				mazeGame.currentScreen = mazeGame.nextScreen;
				mazeGame.nextScreen = null;
				
				// Reset input so that it's not carried on to the next screen
				input.reset();
			}
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
	
	import tile;
	
	enum ASSETS_DIRECTORY = "assets" ~ slash;
	enum SPRITES_DIRECTORY = ASSETS_DIRECTORY ~ "sprites" ~ slash;
	enum MENU_FONT_FILENAME = "assets" ~ slash ~ "text" ~ slash ~ "Munro.ttf";
	
	auto assets = mazeGame.assets;
	
	auto menuFont = assets.menuFont = new Font();
	menuFont.loadFromFile(MENU_FONT_FILENAME);
	
	// Other sprites
	{
		import geometry : Point;
		
		// Load textures
		string[Asset] texturePaths;
		texturePaths[Asset.PusherTexture] = SPRITES_DIRECTORY ~ "pusher.png";
		texturePaths[Asset.GroundTexture] = SPRITES_DIRECTORY ~ "ground.png";
		texturePaths[Asset.WallBackgroundTexture] = SPRITES_DIRECTORY ~ "wall-background.png";
		texturePaths[Asset.WallForegroundTexture] = SPRITES_DIRECTORY ~ "wall-foreground.png";
		texturePaths[Asset.WallOutlineTexture] = SPRITES_DIRECTORY ~ "wall-outline.png";
		texturePaths[Asset.SymbolTexture] = SPRITES_DIRECTORY ~ "symbol.png";
		texturePaths[Asset.ToolsTexture] = SPRITES_DIRECTORY ~ "tools.png";
		
		texturePaths[Asset.BlueprintBG] = SPRITES_DIRECTORY ~ "blueprint-bg.png";
		
		foreach(Asset aKey, string aTexturePath; texturePaths) {
			auto newTexture = new Texture();
			newTexture.loadFromFile(aTexturePath);
			newTexture.setRepeated(true);
			assets.textures[aKey] = newTexture;
		}
		
		// Pusher sprite map
		auto pusherMap = new TextureMap(Point(16, 16));
		assets.maps[Asset.PusherMap] = pusherMap;
		
		pusherMap.addPiece(PusherMapKeys.PusherDown , Point(0, 0));
		pusherMap.addPiece(PusherMapKeys.PusherLeft , Point(0, 1));
		pusherMap.addPiece(PusherMapKeys.PusherRight, Point(0, 2));
		pusherMap.addPiece(PusherMapKeys.PusherUp   , Point(0, 3));
		
		// Ground sprite map
		auto groundMap = new TextureMap(Point(16, 16));
		assets.maps[Asset.GroundMap] = groundMap;
		
		immutable auto exitSpan = IntRect(0, 0, 3, 3);
		immutable auto exitOrigin = Vector2f(1, 1);
		groundMap.addPiece(GroundMapKeys.Exit, exitSpan, exitOrigin);
		
		// Wall sprite map
		auto wallMap = new TextureMap(Point(8, 8));
		assets.maps[Asset.WallMap] = wallMap;
		
		wallMap.addPiece(WallMapKeys.TopLeftSide    , IntRect(0, 0, 2, 2), Vector2f(1, 1));
		wallMap.addPiece(WallMapKeys.TopSide        , IntRect(2, 0, 1, 2), Vector2f(0, 1));
		wallMap.addPiece(WallMapKeys.TopRightSide   , IntRect(3, 0, 2, 2), Vector2f(0, 1));
		wallMap.addPiece(WallMapKeys.RightSide      , IntRect(3, 2, 2, 1), Vector2f(0, 0));
		wallMap.addPiece(WallMapKeys.BottomRightSide, IntRect(3, 3, 2, 2), Vector2f(0, 0));
		wallMap.addPiece(WallMapKeys.BottomSide     , IntRect(2, 3, 1, 2), Vector2f(0, 0));
		wallMap.addPiece(WallMapKeys.BottomLeftSide , IntRect(0, 3, 2, 2), Vector2f(1, 0));
		wallMap.addPiece(WallMapKeys.LeftSide       , IntRect(0, 2, 2, 1), Vector2f(1, 0));
		wallMap.addPiece(WallMapKeys.Fill           , IntRect(9, 0, 2, 2), Vector2f(0, 0));
		
		// Symbol sprite map
		auto symbolMap = new TextureMap(Point(16, 16));
		assets.maps[Asset.SymbolMap] = symbolMap;
		
		symbolMap.addPiece(SymbolMapKeys.MenuSelector, Point(0, 0));
		symbolMap.addPiece(SymbolMapKeys.SquareCursor, IntRect(1, 0, 3, 3), Vector2f(1, 1));
		
		auto toolsMap = new TextureMap(Point(16, 16));
		assets.maps[Asset.ToolsMap] = toolsMap;
		
		toolsMap.addPiece(ToolsMapKeys.SelectionTool, Point(0, 2));
	}
}