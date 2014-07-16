import dsfml.graphics;

import gamescreen;
import geometry;
import stage;

import view;

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
	Font menuFont;
	Drawable[string] sprites;
}

enum Asset {
	MenuSelector = "menu-selector",
}