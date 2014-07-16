import dsfml.graphics;

import gamescreen;
import geometry;
import stage;

import view;

enum BLOCK_SIZE = 16;

class Game {
	RenderWindow window;
	bool isRunning;
	
	GameAssets assets;
	
	GameScreen currentScreen, nextScreen;
	
	RenderTexture buffer;
	View view;
	immutable Vector2u size;
	immutable string title;
	
	VideoResizer resizer;
	
	this(in string title, in uint width, in uint height) {
		this.title = title;
		size = Vector2u(width, height);
		view = new View(FloatRect(Vector2f(0, 0), size.toVector2f));
		
		assets = new GameAssets();
		
		resizer = new VideoResizer(this);
	}
	
	void subtitle(string subtitle) @property {
		enum GAME_SUBTITLE_SEPARATOR = " - ";
		
		if(subtitle is null || subtitle.length == 0) {
			window.setTitle(title);
		} else {
			window.setTitle(title ~ GAME_SUBTITLE_SEPARATOR ~ subtitle);
		}
	}
}

class GameAssets {
	import tile;
	
	Font menuFont;
	Drawable[string] sprites;
	TextureMap[string] maps;
	Texture[string] textures;
}

enum Asset {
	PusherMap = "pusher",
	PusherTexture = "pusher",
	
	GroundMap = "ground",
	GroundTexture = "ground",
	
	WallMap = "wall",
	WallBackgroundTexture = "wall-background",
	WallForegroundTexture = "wall-foreground",
	WallOutlineTexture = "wall-outline",
	
	SymbolMap = "symbol",
	SymbolTexture = "symbol",
}

enum PusherMapKeys {
	PusherUp, PusherLeft, PusherRight, PusherDown,
}

enum GroundMapKeys {
	Exit,
}

enum WallMapKeys {
	TopLeftSide   , TopSide   , TopRightSide   ,
	LeftSide      , Fill      , RightSide      ,
	BottomLeftSide, BottomSide, BottomRightSide,
	
	InnerTopLeftCorner   , InnerTopRightCorner   ,
	InnerBottomLeftCorner, InnerBottomRightCorner,
}

enum SymbolMapKeys {
	MenuSelector,
}