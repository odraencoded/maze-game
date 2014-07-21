debug import std.stdio;
import dsfml.graphics;

import inputbinder;
import gamescreen;
import geometry;
import stage;
import view;

enum GAME_SETTINGS_FILENAME = "maze-settings.yaml";

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
		
		assets = new GameAssets();
		resizer = new VideoResizer(this);
		
		// Setup bindings
		bindings = new InputBinder();
		bindings.forbiddenKeys ~= Keyboard.Key.Escape;
		bindings.forbiddenKeys ~= Keyboard.Key.Return;
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
	
	/++
	 + Save the game settings to a file
	 +/
	void saveSettings(in string filename) {
		import std.file;
		import std.path;
		static import yaml;
		import utility;
		
		debug writeln("Saving game settings to \"" ~ filename ~ "\".");
		
		// Serialize video settings
		auto videoNode = yaml.Node((yaml.Node[string]).init);
		videoNode["scaling mode"] = yaml.Node(resizer.scalingMode);
		videoNode["fullscreen"] = yaml.Node(isFullscreen);
		
		// Serialize key bindings
		auto keyBindingsNode = yaml.Node((yaml.Node[string]).init);
		foreach(Command command, string keyName; BINDING_NAMES) {
			Keyboard.Key boundKey;
			if(bindings.keys.tryGet(command, boundKey)) {
				keyBindingsNode[keyName] = yaml.Node(boundKey);
			}
		}
		
		auto bindingsNode = yaml.Node((yaml.Node[string]).init);
		bindingsNode["keys"] = keyBindingsNode;
		
		// Create root node
		auto rootNode = yaml.Node((yaml.Node[string]).init);
		rootNode["video"] = videoNode;
		rootNode["bindings"] = bindingsNode;
		
		// Write setting file
		auto absoluteFilename = filename.absolutePath;
		mkdirRecurse(absoluteFilename.dirName);
		yaml.Dumper(absoluteFilename).dump(rootNode);
	}
	
	/++
	 + Load the game settings from a file
	 +/
	void loadSettings(string filename) {
		import std.file;
		import std.path;
		static import yaml;
		import moreyaml;
		
		debug writeln("Loading game settings from \"" ~ filename ~ "\".");
		
		auto absoluteFilename = filename.absolutePath;
		yaml.Node root = yaml.Loader(absoluteFilename).load();
		
		// Construct video settings
		_isFullscreen = root["video"]["fullscreen"].as!bool;
		if(_isFullscreen)
			goFullscreen();
		else
			goWindowed();
		
		resizer.scalingMode = root["video"]["scaling mode"].as!ScalingMode;
		
		// Construct key bindings
		foreach(string keyName, Keyboard.Key key; root["bindings"]["keys"]) {
			foreach(Command command, string commandName; BINDING_NAMES) {
				if(commandName == keyName) {
					bindings.keys[command] = key;
					break;
				}
			}
		}
	}
	
	void loadDefaultSettings() {
		// Load default settings
		goWindowed();
		resizer.scalingMode = ScalingMode.Default;
		
		bindings.keys[Command.GoUp         ] = Keyboard.Key.I;
		bindings.keys[Command.GoRight      ] = Keyboard.Key.L;
		bindings.keys[Command.GoDown       ] = Keyboard.Key.K;
		bindings.keys[Command.GoLeft       ] = Keyboard.Key.J;
		bindings.keys[Command.CyclePrevious] = Keyboard.Key.Q;
		bindings.keys[Command.CycleNext    ] = Keyboard.Key.E;
		bindings.keys[Command.Grab         ] = Keyboard.Key.D;
		bindings.keys[Command.Camera       ] = Keyboard.Key.W;
		bindings.keys[Command.Restart      ] = Keyboard.Key.R;
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