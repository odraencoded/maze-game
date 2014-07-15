import std.algorithm;

import dsfml.graphics;

import camera;
import game;
import gamescreen;
import geometry;
import input;
import menuscreen;
import stage;
import stageobject;
import utility;

enum BLOCK_SIZE = 16;

enum CAMERA_SPEED = 8; // X BLOCK_SIZE per BLOCK_SIZE of distance per second
enum CAMERA_CONTROL_FACTOR = 2; // X times as much as above

enum SWITCH_GRIP = false;

enum BACKGROUND_COLOR = Color(96, 96, 96);

class MazeScreen : GameScreen {
	Camera camera;
	Stage stage;
	Pusher player;
	
	VertexArray[int] playerSprites;
	
	void delegate(MazeScreen) onStageComplete;
	
	this(Game game) {
		super(game);
		
		// Setup sprites
		playerSprites = setupPlayerSprites();
		
		// Setup view
		camera = new Camera();
		camera.speed = CAMERA_SPEED;
	}
	
	void setStage(Stage stage) {
		this.stage = stage;
		player = stage.pushers[0];
		game.subtitle = stage.metadata.title;
		camera.reset(player.position.toVector2f);
	}
	
	override void cycle(in InputState input, in float frameDelta) {
		// Change which Pusher the player is controlling
		int cyclePusher = input.getRotation(OnOffState.TurnedOn);
		if(cyclePusher) {
			// Get new pusher for player
			Pusher newPlayer;
			immutable int pusherCount = stage.pushers.length;
			immutable int playerIndex = stage.pushers.countUntil(player);
			int i = (playerIndex + 1) % pusherCount;
			while(i != playerIndex) {
				auto aPusher = stage.pushers[i];
				
				if(aPusher.exit) {
					// Check if there is something over the exit
					bool exitBlocked = false;
					auto obstacles = stage.getObstacles(aPusher.position);
					foreach(StageObject anObstacle; obstacles) {
						if(anObstacle is player)
							continue;
						
						exitBlocked = true;
						break;
					}
					if(!exitBlocked) {
						newPlayer = aPusher;
						break;
					}
				} else {
					newPlayer = aPusher;
					break;
				}
				
				i = (i + 1) % pusherCount;
			}
			
			if(newPlayer) {
				// When a pusher is on the exit and it's not the player
				// it becomes hidden and no longer an obstacle
				if(player.exit) {
					player.obstacle = false;
				}
				
				// Reverting the above
				if(newPlayer.exit) {
					newPlayer.obstacle = true;
				}
				player = newPlayer;
			}
		}
		
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
				player.releaseObject();
		} else if(grabItem) {
			player.grabObject(stage);
		}
		
		// Whether to move the player or the camera
		bool cameraMode = input.isOn(Command.Camera);
		
		bool playerMoved = false;
		if(!cameraMode) {
			// Getting player movement
			Point movement = input.getOffset(OnOffState.TurnedOn);
			playerMoved = movePlayer(movement);
		}
		
		if(playerMoved) {
			player.exit = stage.getExit(player.position);
			if(player.exit) {
				// This pusher has found an exit
				// Check if all pushers are on exits
				bool allOnExit = true;
				foreach(Pusher aPusher; stage.pushers) {
					if(!aPusher.exit) {
						allOnExit = false;
						break;
					}
				}
				
				if(allOnExit) {
					onStageComplete(this);
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
		renderTarget.clear(BACKGROUND_COLOR);
		// Draw exits
		foreach(Exit exit; stage.exits) {
			renderExit(exit, renderTarget);
		}
		
		// Draw player
		foreach(Pusher pusher; stage.pushers) {
			// Do not draw pushers on exit that aren't the player
			if(pusher != player && pusher.exit)
				continue;
			
			RenderStates state;
			state.transform.translate(
				pusher.position.x * BLOCK_SIZE,
				pusher.position.y * BLOCK_SIZE
			);
			
			auto pusherSprite = playerSprites[pusher.facing];
			
			renderTarget.draw(pusherSprite, state);
		}
		
		// Draw walls
		foreach(Wall wall; stage.walls) {
			renderWall(wall, renderTarget);
		}
	}
	
	/**
	 * Tries to move the player, returns whether it was actually moved.
	 */
	private bool movePlayer(scope Point movement) {
		// Quickly return when movement is zero.
		if(movement == Point(0, 0))
			return false;
		
		// Remove second axis from movement
		if(movement.x && movement.y) {
			if(player.facing & Side.Horizontal) 
				movement.x = 0;
			else
				movement.y = 0;
		}
		
		if(!player.isGrabbing && !player.isGrabbed) {
			// Change facing
			changeFacing(player.facing, movement);
		}
		
		immutable Side direction = movement.getDirection();
		immutable bool canMove = player.canMove(stage, direction);
		if(canMove) {
			// Move player
			player.move(stage, direction);
			return true;
		}
		
		return false;
	}
}

private VertexArray[int] setupPlayerSprites() {
	enum PUSHER_COLOR = Color(32, 255, 32);
	VertexArray[int] sprites;
	
	VertexArray down = new VertexArray(PrimitiveType.Triangles, 3);
	down[0].position = Vector2f(2, 2);
	down[1].position = Vector2f(14, 2);
	down[2].position = Vector2f(8, 12);
	for(int i=0; i<3; i++) down[i].color = PUSHER_COLOR;
	
	VertexArray up = new VertexArray(PrimitiveType.Triangles, 3);
	up[0].position = Vector2f(2, 14);
	up[1].position = Vector2f(14, 14);
	up[2].position = Vector2f(8, 4);
	for(int i=0; i<3; i++) up[i].color = PUSHER_COLOR;
	
	VertexArray right = new VertexArray(PrimitiveType.Triangles, 3);
	right[0].position = Vector2f(2, 2);
	right[1].position = Vector2f(2, 14);
	right[2].position = Vector2f(12, 8);
	for(int i=0; i<3; i++) right[i].color = PUSHER_COLOR;
	
	VertexArray left = new VertexArray(PrimitiveType.Triangles, 3);
	left[0].position = Vector2f(14, 2);
	left[1].position = Vector2f(14, 14);
	left[2].position = Vector2f(4, 8);
	for(int i=0; i<3; i++) left[i].color = PUSHER_COLOR;
	
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

private void renderWall(scope Wall wall, scope RenderTarget target) {
	enum GRABBABLE_FILL = Color(0, 0, 0);
	enum FIXED_FILL = Color(128, 0, 0);
	enum GRABBABLE_OUTLINE = Color(255, 255, 255);
	enum GRABBED_OUTLINE = Color(0, 255, 0);
	enum FIXED_OUTLINE = Color(0, 0, 0);
	enum INK_WIDTH = 1;
	
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
		
		if(!joints.hasFlag(Side.Top   )) t += INK_WIDTH;
		if(!joints.hasFlag(Side.Right )) r -= INK_WIDTH;
		if(!joints.hasFlag(Side.Bottom)) b -= INK_WIDTH;
		if(!joints.hasFlag(Side.Left  )) l += INK_WIDTH;
		
		vertexArray[fillIndex + 0].position = Vector2f(l, t);
		vertexArray[fillIndex + 1].position = Vector2f(r, t);
		vertexArray[fillIndex + 2].position = Vector2f(r, b);
		vertexArray[fillIndex + 3].position = Vector2f(l, b);
		
		Color fillColor, inkColor;
		if(wall.isGrabbable) {
			fillColor = GRABBABLE_FILL;
			inkColor = wall.isGrabbed ? GRABBED_OUTLINE : GRABBABLE_OUTLINE;
		} else {
			fillColor = FIXED_FILL;
			inkColor = FIXED_OUTLINE;
		}
		
		for(int j = fillIndex; j < fillIndex + 4; j++)
			vertexArray[j].color = fillColor;
		
		for(int j = inkIndex; j < inkIndex + 4; j++)
			vertexArray[j].color = inkColor;
		
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
	enum exitColor = Color(0, 198, 255);
	
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