import dsfml.graphics;

import inputbinder;
import gamescreen;
import geometry;
import stage;
import view;

enum BLOCK_SIZE = 16;
enum WINDOWED_WINDOW_STYLE = Window.Style.DefaultStyle;
enum FULLSCREEN_WINDOW_STYLE = Window.Style.Fullscreen;

class Game {
	RenderWindow window;
	bool isRunning;
	
	GameAssets assets;
	InputBinder bindings;
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
		
		bindings = new InputBinder();
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
	
	/++
	 + Guesses whether the game is in fullscreen mode.
	 +/
	bool isFullscreen() @property {
		return _isFullscreen;
	}
	
	/++
	 + Goes fullscreen.
	 + Either this or goWindowed must be called before using the game.window.
	 +/
	void goFullscreen() {
		// Destroy previous window.
		if(window)
			window.close();
		
		auto videoMode = VideoMode.getDesktopMode();
		window = new RenderWindow(videoMode, title, FULLSCREEN_WINDOW_STYLE);
		resizer.checkSize();
		_isFullscreen = true;
	}
	
	/++
	 + Goes windowed.
	 + Either this or goFullscreen must be called before using the game.window.
	 +/
	void goWindowed() {
		// Destroy previous window.
		if(window)
			window.close();
		
		auto videoMode = VideoMode(size.x, size.y);
		window = new RenderWindow(videoMode, title, WINDOWED_WINDOW_STYLE);
		resizer.checkSize();
		_isFullscreen = false;
	}
	
private:
	bool _isFullscreen;
}

class GameAssets {
	import tile;
	
	Font menuFont;
	Drawable[string] sprites;
	TextureMap[string] maps;
	Texture[string] textures;
}