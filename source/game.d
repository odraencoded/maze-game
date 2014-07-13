import dsfml.graphics;

import course; 
import gamescreen;
import geometry;
import stage;

import view;

enum GAME_WIDTH = 320;
enum GAME_HEIGHT = 180;
enum GAME_FRAMERATE = 30;
enum GAME_TITLE = "Maze Game";
enum GAME_SUBTITLE_SEPARATOR = " - ";

class Game {
	RenderWindow window;
	bool isRunning;
	
	GameScreen currentScreen, nextScreen;
	
	RenderTexture buffer;
	View view;
	immutable Vector2u size;
	immutable string title;
	
	VideoResizer resizer;
	
	Course course;
	Stage stage;
	int progress;
	
	this(in string title, in uint width, in uint height) {
		this.title = title;
		size = Vector2u(width, height);
		view = new View(FloatRect(Vector2f(0, 0), size.toVector2f));
		
		resizer = new VideoResizer(this);
	}
	
	void subtitle(string subtitle) @property {
		if(subtitle is null || subtitle.length == 0) {
			window.setTitle(title);
		} else {
			window.setTitle(title ~ GAME_SUBTITLE_SEPARATOR ~ subtitle);
		}
	}
}

class Pusher {
	Point position;
	Side facing = Side.Down;
	
	Wall grabbedItem;
	bool isGrabbing() const pure nothrow @safe {
		return !(grabbedItem is null);
	}
	
	void grabItem(Wall item) pure {
		item.isGrabbed = true;
		grabbedItem = item;
	}
	
	void releaseItem() pure {
		grabbedItem.isGrabbed = false;
		grabbedItem = null;
	}
}

class Wall {
	Point position;
	Side[Point] blocks;
	bool isGrabbed;
	bool isFixed;
}

class Exit {
	Point position;
}