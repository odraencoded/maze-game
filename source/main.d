import std.stdio;
import std.algorithm;
import std.path;
import core.memory;

import dsfml.graphics;

import game;
import course;
import geometry;
import utility;

alias slash = dirSeparator;

enum GAME_WIDTH = 320;
enum GAME_HEIGHT = 180;
enum GAME_FRAMERATE = 30;
enum GAME_TITLE = "Maze Game";
enum GAME_TITLE_SEPARATOR = " - ";

enum GO_UP_KEY = Keyboard.Key.I;
enum GO_RIGHT_KEY = Keyboard.Key.L;
enum GO_DOWN_KEY = Keyboard.Key.K;
enum GO_LEFT_KEY = Keyboard.Key.J;
enum GRAB_KEY = Keyboard.Key.D;

enum BLOCK_SIZE = 16;
enum BACKGROUND_COLOR = Color(64, 64, 64, 255);

enum SWITCH_GRIP = false;
enum AUTO_RELEASE = false;
enum CAMERA_SPEED = 8;

enum TEST_PATH = "resources" ~ slash ~ "test";
enum TEST_COURSE_PATH = TEST_PATH ~ slash  ~ "course";

void main(string[] args) {
	Game game = new Game();
	
	// Open Window
	auto window = game.window = setupWindow();
	auto camera = new Camera();
	camera.speed = CAMERA_SPEED;
	auto cameraView = new View();
	cameraView.reset(FloatRect(0, 0, GAME_WIDTH, GAME_HEIGHT));
	
	// Setup game course
	// If a directory wasn't passed in the arguments, load the test course
	string coursePath = args.length > 1 ? args[1] : TEST_COURSE_PATH;
	auto course = game.course = coursePath.loadCourse();
	game.progress = 0;
	
	// Setup first stage
	auto stage = game.stage = game.course.buildStage(game.progress);
	auto player = stage.player;
	setTitleFromStage(game.window, stage);
	
	// Setup input
	OnOffState[int] input;
	input[GO_UP_KEY] = OnOffState.Off;
	input[GO_RIGHT_KEY] = OnOffState.Off;
	input[GO_DOWN_KEY] = OnOffState.Off;
	input[GO_LEFT_KEY] = OnOffState.Off;
	input[GRAB_KEY] = OnOffState.Off;
	
	Point[int] directionalKeys;
	directionalKeys[GO_UP_KEY   ] = Point( 0, -1);
	directionalKeys[GO_RIGHT_KEY] = Point( 1,  0);
	directionalKeys[GO_DOWN_KEY ] = Point( 0,  1);
	directionalKeys[GO_LEFT_KEY ] = Point(-1,  0);
	
	// Setup sprites
	VertexArray[int] playerSprites = setupPlayerSprites();
	
	// Main loop
	game.isRunning = true;
	while(true) {
		// Fixed delta
		enum frameDelta = 1.0 / GAME_FRAMERATE;
		
		// Updating input register
		foreach(int key, OnOffState value; input) {
			input[key] = value & ~OnOffState.Changed;
		}
		
		// Polling events
		Event event;
		while(window.pollEvent(event)) {
			switch(event.type) {
				// Close window
				case(event.EventType.Closed):
					window.close();
					break;
				
				// Register input
				case(event.EventType.KeyPressed):
					auto code = event.key.code;
					if(code in input)
						input[code] = OnOffState.TurnedOn;
					break;
				
				case(event.EventType.KeyReleased):
					auto code = event.key.code;
					if(code in input)
						input[code] = OnOffState.TurnedOff;
					break;
				
				default:
			}
		}
		
		// Exiting loop
		game.isRunning = game.isRunning && window.isOpen();
		if(!game.isRunning)
			break;
		
		// Grab walls
		bool grabItem, releaseItem;
		if(SWITCH_GRIP) {
			// Press once = on, press again = off
			if(input[GRAB_KEY].hasFlag(OnOffState.TurnedOn)) {
				if(player.isGrabbing)
					releaseItem = true;
				else
					grabItem = true;
			}
		} else {
			// Hold key = on, release key = off
			if(input[GRAB_KEY].hasFlag(OnOffState.On))
				grabItem = true;
			else
				releaseItem = true;
		}
		
		if(player.isGrabbing) {
			if(releaseItem)
				player.releaseItem();
		} else {
			if(grabItem) {
				auto wall = stage.getItem(player.position, player.facing);
				if(wall && !wall.isFixed)
					player.grabItem(wall);
			}
		}
		
		// Move player
		enum keyFlag = OnOffState.TurnedOn;
		Point movement;
		foreach(int key, Point offset; directionalKeys)
			if(input[key].hasFlag(keyFlag))
				movement += offset;
		
		bool playerMoved = movePlayer(game, movement);
		
		if(playerMoved) {
			if(stage.isOnExit(player.position)) {
				// Change to the next stage
				game.progress++;
				if(game.progress < game.course.length) {
					stage = game.stage = game.course.buildStage(game.progress);
					player = stage.player;
					setTitleFromStage(game.window, stage);
				} else {
					// TODO: anything else!
					return;
				}
			}
		}
		
		// Update camera
		camera.moveFocus(player.position.to!Vector2f);
		camera.update(frameDelta);
		
		// Draw stuff
		window.clear(BACKGROUND_COLOR);
		
		// Set camera
		enum centeringOffset = Vector2f(.5f, .5f);
		cameraView.center = (camera.center + centeringOffset) * BLOCK_SIZE;
		cameraView.center = cameraView.center.round;
		window.view = cameraView;
		
		// Draw exits
		foreach(Exit exit; stage.exits) {
			renderExit(exit, window);
		}
		
		// Draw player
		RenderStates state;
		state.transform.translate(
			player.position.x * BLOCK_SIZE,
			player.position.y * BLOCK_SIZE
		);
		
		auto playerSprite = playerSprites[player.facing];
		
		window.draw(playerSprite, state);
		
		// Draw walls
		foreach(Wall wall; stage.walls) {
			renderWall(wall, window);
		}
		
		
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

private VertexArray[int] setupPlayerSprites() {
	VertexArray[int] sprites;
	
	VertexArray down = new VertexArray(PrimitiveType.Triangles, 3);
	down[0].position = Vector2f(2, 2);
	down[1].position = Vector2f(14, 2);
	down[2].position = Vector2f(8, 12);
	for(int i=0; i<3; i++) down[i].color = Color.White;
	
	VertexArray up = new VertexArray(PrimitiveType.Triangles, 3);
	up[0].position = Vector2f(2, 14);
	up[1].position = Vector2f(14, 14);
	up[2].position = Vector2f(8, 4);
	for(int i=0; i<3; i++) up[i].color = Color.White;
	
	VertexArray right = new VertexArray(PrimitiveType.Triangles, 3);
	right[0].position = Vector2f(2, 2);
	right[1].position = Vector2f(2, 14);
	right[2].position = Vector2f(12, 8);
	for(int i=0; i<3; i++) right[i].color = Color.White;
	
	VertexArray left = new VertexArray(PrimitiveType.Triangles, 3);
	left[0].position = Vector2f(14, 2);
	left[1].position = Vector2f(14, 14);
	left[2].position = Vector2f(4, 8);
	for(int i=0; i<3; i++) left[i].color = Color.White;
	
	sprites[Side.Up] = up;
	sprites[Side.Down] = down;
	sprites[Side.Left] = left;
	sprites[Side.Right] = right;
	
	return sprites;
}

private void changeFacing(ref Side facing, Point direction) {
	if(direction.x != 0) {
		if(direction.y != 0 && (facing & Side.Vertical) != 0) {
			goto VerticalFacingCheck;
		}
		
		if (direction.x < 0) {
			facing = Side.Left;
		} else {
			facing = Side.Right;
		}
	} else {
		VerticalFacingCheck:
		if(direction.y < 0)
			facing = Side.Up;
		else if(direction.y > 0)
			facing = Side.Down;
	}
}

private void renderWall(Wall wall, RenderTarget target) {
	enum ungrabbedColor = Color.Black;
	enum grabbedColor = Color.Red;
	enum inkColor = Color.White;
	enum inkWidth = 1;
	
	const int vertexCount = 8 * wall.blocks.length;
	auto vertexArray = new VertexArray(PrimitiveType.Quads, vertexCount);
	
	foreach(int i, Point block; wall.blocks) {
		const int fillIndex = i * 8 + 4;
		const int inkIndex = i * 8;
		
		int t, r, b, l;
		t = block.y * BLOCK_SIZE;
		r = (block.x + 1) * BLOCK_SIZE;
		b = (block.y + 1) * BLOCK_SIZE;
		l = block.x * BLOCK_SIZE;
		
		vertexArray[inkIndex + 0].position = Vector2f(l, t);
		vertexArray[inkIndex + 1].position = Vector2f(r, t);
		vertexArray[inkIndex + 2].position = Vector2f(r, b);
		vertexArray[inkIndex + 3].position = Vector2f(l, b);
		
		bool[int] outlines;
		outlines[Side.Top   ] = !canFind(wall.blocks, block + Point( 0, -1));
		outlines[Side.Right ] = !canFind(wall.blocks, block + Point( 1,  0));
		outlines[Side.Bottom] = !canFind(wall.blocks, block + Point( 0,  1));
		outlines[Side.Left  ] = !canFind(wall.blocks, block + Point(-1,  0));
		
		if(outlines[Side.Top   ]) t += inkWidth;
		if(outlines[Side.Right ]) r -= inkWidth;
		if(outlines[Side.Bottom]) b -= inkWidth;
		if(outlines[Side.Left  ]) l += inkWidth;
		
		vertexArray[fillIndex + 0].position = Vector2f(l, t);
		vertexArray[fillIndex + 1].position = Vector2f(r, t);
		vertexArray[fillIndex + 2].position = Vector2f(r, b);
		vertexArray[fillIndex + 3].position = Vector2f(l, b);
		
		auto fillColor = wall.isGrabbed ? grabbedColor : ungrabbedColor;
		
		for(int j = fillIndex; j < fillIndex + 4; j++)
			vertexArray[j].color = fillColor;
		
		for(int j = inkIndex; j < inkIndex + 4; j++)
			vertexArray[j].color = wall.isFixed ? fillColor : inkColor;
	}

	RenderStates states;
	states.transform.translate(
		wall.position.x * BLOCK_SIZE,
		wall.position.y * BLOCK_SIZE
	);
	
	target.draw(vertexArray, states);
}

private void renderExit(Exit exit, RenderTarget target) {
	enum exitColor = Color.White;
	
	auto vertexArray = new VertexArray(PrimitiveType.Quads, 4);
	
	int t, r, b, l;
	l = t = 0;
	b = r = BLOCK_SIZE;
	
	vertexArray[0].position = Vector2f(l, t);
	vertexArray[1].position = Vector2f(r, t);
	vertexArray[2].position = Vector2f(r, b);
	vertexArray[3].position = Vector2f(l, b);
	
	for(int i=0; i < 4; i++)
		vertexArray[i].color = exitColor;
	
	RenderStates states;
	states.transform.translate(
		exit.position.x * BLOCK_SIZE,
		exit.position.y * BLOCK_SIZE
	);
	
	target.draw(vertexArray, states);
}

private void setTitleFromStage(Window window, Stage stage) {
	if(stage.title.length) {
		window.setTitle(stage.title ~ GAME_TITLE_SEPARATOR ~ GAME_TITLE);
	} else {
		window.setTitle(GAME_TITLE);
	}
}

/**
 * Tries to move the player, returns whether it was actually moved.
 */
private bool movePlayer(Game game, Point movement) {
	// Quickly return when movement is zero.
	if(movement == Point(0, 0))
		return false;
	
	// Memoize stuff
	auto stage = game.stage;
	auto player = stage.player;
	
	
	// Remove second axis from movement
	if(movement.x && movement.y) {
		if(player.facing & Side.Horizontal) 
			movement.x = 0;
		else
			movement.y = 0;
	}
	
	Side direction = getDirection(movement);
	
	// Check if grabbed item can move
	bool canGrabMove = false;
	if(player.isGrabbing) {
		canGrabMove = true;
		foreach(Point block; player.grabbedItem.blocks) {
			block += player.grabbedItem.position;
			if(!stage.canGo(block, direction, true)) {
				canGrabMove = false;
				break;
			}
		}
	}
	
	// Check if player can move
	bool canMove;
	if(!AUTO_RELEASE && player.isGrabbing && !canGrabMove)
		// If AUTO_RELEASE is off and the grab can't move,
		// the player can't move either
		canMove = false;
	else
		canMove = stage.canGo(player.position, direction, canGrabMove);
	
	if(canMove) {
		if(canGrabMove) {
			// Grab exists and can move
			// Move grabbed item, don't change facing
			player.grabbedItem.position += movement;
		} else {
			// Grab can't move, but player can
			// Release grabbed item and change facing
			if(player.isGrabbing)
				player.releaseItem();
			
			changeFacing(player.facing, movement);
		}
		
		// Move player
		player.position += movement;
		return true;
	} else if(!player.isGrabbing) {
		// Can't move, but isn't grabbing anything, just change facing
		changeFacing(player.facing, movement);
	}
	
	return false;
}