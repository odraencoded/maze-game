import dsfml.graphics;

import assetcodes;
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
		updateCachedWalls();
	}
	
	void updateCachedWalls() {
		updateCachedWalls(stage.walls, cachedWallSprites);
	}
	
	protected void updateCachedWalls(Wall[] walls, ref VertexCache[Wall] cache) {
		cache.clear();
		auto wallMap = gameAssets.maps[Asset.WallMap];
		foreach(Wall aWall; walls) {
			cache[aWall] = aWall.createSpriteCache(wallMap);
		}
	}
	
	void draw(RenderTarget renderTarget, RenderStates states) {
		if(!(stage is null)) {
			renderExits(renderTarget);
			renderWalls(renderTarget);
			renderPushers(renderTarget);
		}
	}
	
	protected bool isVisible(Pusher pusher) { return true; }
	protected bool isVisible(Wall wall) { return true; }
	protected bool isVisible(Exit exit) { return true; }
	protected int getSpriteKey(Pusher pusher) {
		return PUSHER_FACING_TO_KEY_TABLE[pusher.facing];
	}
	
	protected void renderExits(RenderTarget renderTarget) {
		renderExits(stage.exits, renderTarget);
	}
	
	protected void renderExits(Exit[] exits, RenderTarget renderTarget) {
		// Draw exits
		auto exitSpriteMap = gameAssets.maps[Asset.GroundMap];
		auto exitSprite = new TileSprite();
		exitSprite.texture = &gameAssets.textures[Asset.GroundTexture];
		exitSprite.piece = exitSpriteMap[GroundMapKeys.Exit];
		foreach(Exit exit; exits) {
			if(!isVisible(exit))
				continue;
			
			exitSprite.position = exit.position * BLOCK_SIZE;
			renderTarget.draw(exitSprite);
		}
	}
	
	protected void renderPushers(RenderTarget renderTarget) {
		renderPushers(stage.pushers, renderTarget);
	}
	
	protected void renderPushers(Pusher[] pushers, RenderTarget renderTarget) {
		// Draw player
		auto pusherSpriteMap = gameAssets.maps[Asset.PusherMap];
		auto pusherSprite = new TileSprite();
		pusherSprite.texture = &gameAssets.textures[Asset.PusherTexture];
		
		foreach(Pusher pusher; pushers) {
			if(!isVisible(pusher))
				continue;
			
			pusherSprite.position = pusher.position * BLOCK_SIZE;
			
			immutable auto spriteKey = getSpriteKey(pusher);
			pusherSprite.piece = pusherSpriteMap[spriteKey];
			
			renderTarget.draw(pusherSprite);
		}
	}
	
	protected void renderWalls(RenderTarget target) {
		renderWalls(cachedWallSprites, target);
	}
	
	protected void renderWalls(VertexCache[Wall] walls, RenderTarget target) {
		Texture* currentTexture;
		// Render wall background
		currentTexture = &gameAssets.textures[Asset.WallBackgroundTexture];
		foreach(Wall aWall, VertexCache aCache; walls) {
			aCache.position = aWall.position * BLOCK_SIZE;
			aCache.texture = currentTexture;
			target.draw(aCache);
		}
		
		// Render wall foregronud
		currentTexture = &gameAssets.textures[Asset.WallForegroundTexture];
		foreach(Wall aWall, VertexCache aCache; walls) {
			aCache.texture = currentTexture;
			target.draw(aCache);
		}
		
		// Render wall outline
		currentTexture = &gameAssets.textures[Asset.WallOutlineTexture];
		VertexCache[] grabbedWalls;
		foreach(Wall aWall, VertexCache aCache; walls) {
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
