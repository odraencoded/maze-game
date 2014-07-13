import std.algorithm;

import dsfml.graphics;

import camera;
import game;
import gamescreen;
import geometry;
import input;
import menuscreen;
import stage;
import utility;

enum BLOCK_SIZE = 16;

enum CAMERA_SPEED = 8; // X BLOCK_SIZE per BLOCK_SIZE of distance per second
enum CAMERA_CONTROL_FACTOR = 2; // X times as much as above

enum SWITCH_GRIP = false;
enum AUTO_RELEASE = false;

class MazeScreen : GameScreen {
	Camera camera;
	Stage stage;
	Pusher player;
	
	VertexArray[int] playerSprites;
	
	this(Game game) {
		super(game);
		
		// Setup sprites
		playerSprites = setupPlayerSprites();
		
		// Setup view
		camera = new Camera();
		camera.speed = CAMERA_SPEED;
		
		stage = game.stage;
		player = stage.player;
		game.subtitle = stage.metadata.title;
		camera.reset(player.position.toVector2f);
	}
	
	override void cycle(in InputState input, in float frameDelta) {
		// Grab walls
		bool grabItem, releaseItem;
		if(SWITCH_GRIP) {
			// Press once = on, press again = off
			if(input.wasTurnedOn(Command.Grab)) {
				if(player.isGrabbing)
					releaseItem = true;
				else
					grabItem = true;
			}
		} else {
			// Hold key = on, release key = off
			if(input.isOn(Command.Grab))
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
		
		// Whether to move the player or the camera
		bool cameraMode = input.isOn(Command.Camera);
		
		bool playerMoved = false;
		if(!cameraMode) {
			// Getting player movement
			Point movement = input.getOffset(OnOffState.TurnedOn);
			playerMoved = movePlayer(game, movement);
		}
		
		if(playerMoved) {
			if(stage.isOnExit(player.position)) {
				// Change to the next stage
				game.progress++;
				if(game.progress < game.course.length) {
					stage = game.stage = game.course.buildStage(game.progress);
					player = stage.player;
					game.subtitle = stage.metadata.title;
					camera.reset(player.position.toVector2f);
				} else {
					game.nextScreen = new MenuScreen(game);
				}
			}
		}
		
		// Update camera
		if(cameraMode) {
			// Getting camera movement
			Point movement = input.getOffset(OnOffState.On);
			camera.focus = camera.center + movement * CAMERA_CONTROL_FACTOR;
		} else {
			camera.focus = player.position.toVector2f;
		}
		camera.update(frameDelta);
		
		// Update view
		enum CENTERING_OFFSET = Vector2f(.5f, .5f);
		auto cameraView = game.view;
		cameraView.center = (camera.center + CENTERING_OFFSET) * BLOCK_SIZE;
		cameraView.center = cameraView.center.round;
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		// Draw exits
		foreach(Exit exit; stage.exits) {
			renderExit(exit, renderTarget);
		}
		
		// Draw player
		RenderStates state;
		state.transform.translate(
			player.position.x * BLOCK_SIZE,
			player.position.y * BLOCK_SIZE
		);
		
		auto playerSprite = playerSprites[player.facing];
		
		renderTarget.draw(playerSprite, state);
		
		// Draw walls
		foreach(Wall wall; stage.walls) {
			renderWall(wall, renderTarget);
		}
	}
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

private void changeFacing(ref Side facing, in Point direction) pure {
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

private void renderWall(in Wall wall, scope RenderTarget target) {
	enum ungrabbedColor = Color.Black;
	enum grabbedColor = Color.Red;
	enum inkColor = Color.White;
	enum inkWidth = 1;
	
	const int vertexCount = 8 * wall.blocks.length;
	auto vertexArray = new VertexArray(PrimitiveType.Quads, vertexCount);
	
	int i = 0;
	foreach(Point block,  Side joints; wall.blocks) {
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
		
		if(!joints.hasFlag(Side.Top   )) t += inkWidth;
		if(!joints.hasFlag(Side.Right )) r -= inkWidth;
		if(!joints.hasFlag(Side.Bottom)) b -= inkWidth;
		if(!joints.hasFlag(Side.Left  )) l += inkWidth;
		
		vertexArray[fillIndex + 0].position = Vector2f(l, t);
		vertexArray[fillIndex + 1].position = Vector2f(r, t);
		vertexArray[fillIndex + 2].position = Vector2f(r, b);
		vertexArray[fillIndex + 3].position = Vector2f(l, b);
		
		auto fillColor = wall.isGrabbed ? grabbedColor : ungrabbedColor;
		
		for(int j = fillIndex; j < fillIndex + 4; j++)
			vertexArray[j].color = fillColor;
		
		for(int j = inkIndex; j < inkIndex + 4; j++)
			vertexArray[j].color = wall.isFixed ? fillColor : inkColor;
		
		i++;
	}

	RenderStates states;
	states.transform.translate(
		wall.position.x * BLOCK_SIZE,
		wall.position.y * BLOCK_SIZE
	);
	
	target.draw(vertexArray, states);
}

private void renderExit(in Exit exit, scope RenderTarget target) {
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

/**
 * Tries to move the player, returns whether it was actually moved.
 */
private bool movePlayer(scope Game game, scope Point movement) pure {
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
		foreach(Point block, Side joints; player.grabbedItem.blocks) {
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