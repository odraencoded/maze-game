import dsfml.graphics;

import game;
import geometry;
import stage;
import stageobject;
import tile;

class StageRenderer : Drawable {
	GameAssets gameAssets;
	Stage stage;
	
	VertexCache[Wall] cachedWallSprites;
	
	this(GameAssets gameAssets) {
		this.gameAssets = gameAssets;
	}
	
	void setStage(Stage stage) {
		this.stage = stage;
		
		// Cache walls
		auto wallMap = gameAssets.maps[Asset.WallMap];
		cachedWallSprites.clear();
		foreach(Wall aWall; stage.walls) {
			cachedWallSprites[aWall] = aWall.createSpriteCache(wallMap);
		}
	}
	
	void draw(RenderTarget renderTarget, RenderStates states) {
		if(!(stage is null)) {
			renderExits(renderTarget);
			renderPushers(renderTarget);
			renderWalls(renderTarget);
		}
	}
	
	protected bool isVisible(Pusher pusher) { return true; }
	protected bool isVisible(Wall wall) { return true; }
	protected bool isVisible(Exit exit) { return true; }
	protected int getSpriteKey(Pusher pusher) {
		return PUSHER_FACING_TO_KEY_TABLE[pusher.facing];
	}
	
	protected void renderExits(RenderTarget renderTarget) {
		// Draw exits
		auto exitSpriteMap = gameAssets.maps[Asset.GroundMap];
		auto exitSprite = new TileSprite();
		exitSprite.texture = &gameAssets.textures[Asset.GroundTexture];
		exitSprite.piece = &exitSpriteMap[GroundMapKeys.Exit];
		foreach(Exit exit; stage.exits) {
			if(!isVisible(exit))
				continue;
			
			exitSprite.position = exit.position * BLOCK_SIZE;
			renderTarget.draw(exitSprite);
		}
	}
	
	protected void renderPushers(RenderTarget renderTarget) {
		// Draw player
		auto pusherSpriteMap = gameAssets.maps[Asset.PusherMap];
		auto pusherSprite = new TileSprite();
		pusherSprite.texture = &gameAssets.textures[Asset.PusherTexture];
		
		foreach(Pusher pusher; stage.pushers) {
			if(!isVisible(pusher))
				continue;
			
			pusherSprite.position = pusher.position * BLOCK_SIZE;
			
			immutable auto spriteKey = getSpriteKey(pusher);
			pusherSprite.piece = &pusherSpriteMap[spriteKey];
			
			renderTarget.draw(pusherSprite);
		}
	}
	
	protected void renderWalls(RenderTarget target) {
		Texture* currentTexture;
		
		// Render wall background
		currentTexture = &gameAssets.textures[Asset.WallBackgroundTexture];
		foreach(Wall aWall, VertexCache aCache; cachedWallSprites) {
			aCache.position = aWall.position * BLOCK_SIZE;
			aCache.texture = currentTexture;
			target.draw(aCache);
		}
		
		// Render wall foregronud
		currentTexture = &gameAssets.textures[Asset.WallForegroundTexture];
		foreach(Wall aWall, VertexCache aCache; cachedWallSprites) {
			aCache.texture = currentTexture;
			target.draw(aCache);
		}
		
		// Render wall outline
		currentTexture = &gameAssets.textures[Asset.WallOutlineTexture];
		VertexCache[] grabbedWalls;
		foreach(Wall aWall, VertexCache aCache; cachedWallSprites) {
			if(aWall.isGrabbable) {
				aCache.texture = currentTexture;
				
				if(aWall.isGrabbed) {
					grabbedWalls ~= aCache;
				} else {
					target.draw(aCache);
				}
			}
		}
		
		// Grabbed walls' outlines rendered last so they appear in front
		// of normal walls outlines.
		foreach(VertexCache aCache; grabbedWalls) {
			enum GRABBED_OUTLINE_COLOR = Color(0, 255, 0);
			enum NORMAL_OUTLINE_COLOR = Color(255, 255, 255);
			
			// Set cool outline
			aCache.setColor(GRABBED_OUTLINE_COLOR);
			target.draw(aCache);
			
			// Unset said cool outline
			aCache.setColor(NORMAL_OUTLINE_COLOR);
		}
	}
}

class MazeScreenStageRenderer : StageRenderer {
	import mazescreen;
	
	MazeScreen screen;
	
	this(GameAssets assets, MazeScreen screen) {
		super(assets);
		this.screen = screen;
	}
	
	protected override bool isVisible(Pusher pusher) {
		return pusher.exit is null || pusher == screen.player;
	}
}

static immutable int[int] PUSHER_FACING_TO_KEY_TABLE;

static this() {
	PUSHER_FACING_TO_KEY_TABLE[Side.Up   ] = PusherMapKeys.PusherUp;
	PUSHER_FACING_TO_KEY_TABLE[Side.Down ] = PusherMapKeys.PusherDown;
	PUSHER_FACING_TO_KEY_TABLE[Side.Left ] = PusherMapKeys.PusherLeft;
	PUSHER_FACING_TO_KEY_TABLE[Side.Right] = PusherMapKeys.PusherRight;
}