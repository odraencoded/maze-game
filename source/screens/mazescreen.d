import std.algorithm;

import dsfml.graphics;

import camera;
import game;
import gamescreen;
import geometry;
import input;
import menu;
import menuscreen;
import signal;
import stage;
import stageobject;
import stagerenderer;
import utility;
import tile;

enum CAMERA_SPEED = 8; // X BLOCK_SIZE per BLOCK_SIZE of distance per second
enum CAMERA_CONTROL_FACTOR = 2; // X times as much as above

enum SWITCH_GRIP = false;

enum BACKGROUND_COLOR = Color(192, 192, 192);

class MazeScreen : GameScreen {
	Camera camera;
	Stage stage;
	Pusher player;
	
	// Events
	Signal!(MazeScreen) onStageComplete, onQuit, onRestart;
	
	MazeScreenStageRenderer stageRenderer;
	
	this(Game game) {
		super(game);
		
		// Setup view
		camera = new Camera();
		camera.speed = CAMERA_SPEED;
		
		stageRenderer = new MazeScreenStageRenderer(game.assets, this);
	}
	
	void setStage(Stage stage) {
		this.stage = stage;
		player = stage.pushers[0];
		game.subtitle = stage.metadata.title;
		camera.reset(player.position.toVector2f);
		
		stageRenderer.setStage(stage);
	}
	
	override void cycle(in InputState input, in float delta) {
		bool pauseGame = false;
		pauseGame |= input.wasKeyTurnedOn(SystemKey.Escape);
		pauseGame |= input.lostFocus;
		
		if(pauseGame) {
			auto pauseScreen = new PauseMenuScreen(game, this);
			game.nextScreen = pauseScreen;
			return;
		}
		
		// Change which Pusher the player is controlling
		int cyclingDirection = input.getRotation(OnOffState.TurnedOn);
		cycleThroughPushers(cyclingDirection);
		
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
		
		cycleCamera(input, delta);
		
		if(input.wasTurnedOn(Command.Restart)) {
			onRestart(this);
		}
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		import tile;
		
		renderTarget.clear(BACKGROUND_COLOR);
		
		// Update view
		enum CENTERING_OFFSET = Vector2f(.5f, .5f);
		auto gameSize = game.view.size;
		auto viewCenter = (camera.center + CENTERING_OFFSET) * BLOCK_SIZE;
		auto viewTopLeft = (viewCenter - gameSize / 2).round;
		auto viewRect = FloatRect(viewTopLeft, gameSize);
		renderTarget.view = new View(viewRect);
		
		renderTarget.draw(stageRenderer);
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
	
	/++
	 + Updates camera position.
	 +/
	private void cycleCamera(in InputState input, in float delta) {
		// Update camera
		bool cameraMode = input.isOn(Command.Camera);
		if(cameraMode) {
			// Getting camera movement
			Point movement = input.getOffset(OnOffState.On);
			camera.focus = camera.center + movement * CAMERA_CONTROL_FACTOR;
		} else {
			camera.focus = player.position.toVector2f;
		}
		camera.update(delta);
	}
	
	/++
	 + Change player to the next/previous pusher
	 +/
	void cycleThroughPushers(in int direction) {
		if(direction == 0)
			return;
		
		// Get new pusher for player
		Pusher newPlayer;
		immutable int pusherCount = stage.pushers.length;
		immutable int playerIndex = stage.pushers.countUntil(player);
		int i = (playerIndex + direction + pusherCount) % pusherCount;
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
}

/++
 + Shows a pause menu over a MazeScreen
 +/
class PauseMenuScreen : GameScreen {
	MenuContext menuContext;
	MazeScreen mazeScreen;
	
	this(Game game, MazeScreen screen) {
		super(game);
		
		// Create the menu
		this.mazeScreen = screen;
		menuContext = new MenuContext(game.assets);
		
		auto resumeMenuItem = menuContext.createMenuItem("Resume");
		auto restartMenuItem = menuContext.createMenuItem("Restart");
		auto quitMenuItem = menuContext.createMenuItem("Quit");
		auto pauseMenu = new Menu();
		pauseMenu.items = [resumeMenuItem, restartMenuItem, quitMenuItem];
		
		// Cancelling the pauseMenu returns to the game
		auto resumeGame = { game.nextScreen = mazeScreen; };
		pauseMenu.onCancel ~= resumeGame;
		resumeMenuItem.onActivate ~= resumeGame;
		
		// Restart level
		restartMenuItem.onActivate ~= {
			mazeScreen.onRestart(mazeScreen);
			resumeGame();
		};
		
		// Quit to menu
		quitMenuItem.onActivate ~= { mazeScreen.onQuit(mazeScreen); };
		
		menuContext.currentMenu = pauseMenu;
	}
	
	override void cycle(in InputState input, in float frameDelta) {
		menuContext.cycle(input, frameDelta);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		// Draw background
		mazeScreen.draw(renderTarget, states);
		
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