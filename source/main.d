import dsfml.graphics;
import std.stdio;
import std.algorithm;
import game;

enum GAME_WIDTH = 320;
enum GAME_HEIGHT = 180;
enum GAME_FRAMERATE = 30;
enum GAME_TITLE = "Maze Game";

enum GO_UP_KEY = Keyboard.Key.I;
enum GO_RIGHT_KEY = Keyboard.Key.L;
enum GO_DOWN_KEY = Keyboard.Key.K;
enum GO_LEFT_KEY = Keyboard.Key.J;

enum BLOCK_SIZE = 16;
enum BACKGROUND_COLOR = Color(64, 64, 64, 255);

void main(string[] args) {
	Game game = new Game();
	
	// Open Window
	auto window = game.window = setupWindow();
	
	// Create test stage
	auto stage = game.stage = setupTestStage();
	auto player = stage.player;
	
	// Setup input
	OnOffState[int] input;
	input[GO_UP_KEY] = OnOffState.Off;
	input[GO_RIGHT_KEY] = OnOffState.Off;
	input[GO_DOWN_KEY] = OnOffState.Off;
	input[GO_LEFT_KEY] = OnOffState.Off;
	
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
		
		// Move player
		Point movement;
		if(input[GO_UP_KEY] == OnOffState.TurnedOn)
			movement.y -= 1;
		if(input[GO_DOWN_KEY] == OnOffState.TurnedOn)
			movement.y += 1;
		if(input[GO_LEFT_KEY] == OnOffState.TurnedOn)
			movement.x -= 1;
		if(input[GO_RIGHT_KEY] == OnOffState.TurnedOn)
			movement.x += 1;
		
		// Change facing
		changeFacing(player.facing, movement);
		player.position += movement;
		
		// Draw stuff
		window.clear(BACKGROUND_COLOR);
		
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
	}
}

private RenderWindow setupWindow() {
	auto videoMode = VideoMode(GAME_WIDTH, GAME_HEIGHT);
	auto window = new RenderWindow(videoMode, GAME_TITLE);
	window.setFramerateLimit(GAME_FRAMERATE);
	return window;
}

private Stage setupTestStage() {
	auto stage = new Stage();
	stage.player = new Pusher();
	
	// Setup test walls
	auto LWall = new Wall();
	LWall.blocks = [
		Point(0, 0),
		Point(0, 1),
		Point(0, 2), Point(1, 2),
	];
	LWall.position = Point(3, 3);
	stage.walls ~= LWall;
	
	return stage;
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
	enum fillColor = Color.Black;
	enum inkColor = Color.White;
	
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
		
		if(outlines[Side.Top   ]) t += BLOCK_SIZE / 8;
		if(outlines[Side.Right ]) r -= BLOCK_SIZE / 8;
		if(outlines[Side.Bottom]) b -= BLOCK_SIZE / 8;
		if(outlines[Side.Left  ]) l += BLOCK_SIZE / 8;
		
		vertexArray[fillIndex + 0].position = Vector2f(l, t);
		vertexArray[fillIndex + 1].position = Vector2f(r, t);
		vertexArray[fillIndex + 2].position = Vector2f(r, b);
		vertexArray[fillIndex + 3].position = Vector2f(l, b);
		
		for(int j = fillIndex; j < fillIndex + 4; j++)
			vertexArray[j].color = fillColor;
		for(int j = inkIndex; j < inkIndex + 4; j++)
			vertexArray[j].color = inkColor;
	}
	
	RenderStates states;
	states.transform.translate(
		wall.position.x * BLOCK_SIZE,
		wall.position.y * BLOCK_SIZE
	);
	
	target.draw(vertexArray, states);
}