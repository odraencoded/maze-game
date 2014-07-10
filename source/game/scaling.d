module scaling;

import std.algorithm;
import std.math;
import std.stdio;
import dsfml.graphics;

import game;
import geometry;

enum ERROR_BUFFER_CREATION_MESSAGE = "Couldn't create rendering buffer";

/**
 * Manages the scale and size of the game view.
 */
class VideoResizer : Drawable {
	Game game;
	
	this(Game game) {
		this.game = game;
		_bufferSprite = new Sprite();
	}
	
	/++
	 + Call when the window has been resized in order for it to work.
	 +/
	void checkSize() {
		Vector2u windowSize = game.window.size;
		
		// Update game window view size to window size
		auto viewRect = FloatRect(Vector2f(0, 0), windowSize.to!Vector2f);
		game.window.view = new View(viewRect);
		
		// The game.window.size must be greater or equal to game.size
		if(windowSize.x < game.size.x || windowSize.y < game.size.y) {
			uint newWidth = max(windowSize.x, game.size.x);
			uint newHeight = max(windowSize.y, game.size.y);
			game.window.size = Vector2u(newWidth, newHeight);
		} else {
			// Resizing the view of the game.
			// Given a window width of 521 and a game width of 250 for example
			// magnification should be 2
			// view width should be 522 (521 rounded up by magnification)
			// buffer width should be 522
			// window.view.size.x should be 521
			
			// Get the smallest scale between the two sides, such that
			// neither dimension of game.size * scale is greater than
			// window.size
			Vector2f scale;
			scale.x = windowSize.x / cast(float)game.size.x;
			scale.y = windowSize.y / cast(float)game.size.y;
			float smallestScale = min(scale.x, scale.y);
			
			// Get magnification, update buffer sprite scale
			auto magnification = cast(float)floor(smallestScale);
			_bufferSprite.scale = Vector2f(magnification, magnification);
			
			// Calculate game view size
			Vector2u viewSize;
			viewSize.x = cast(uint)ceil(windowSize.x / magnification);
			viewSize.y = cast(uint)ceil(windowSize.y / magnification);
			
			game.view.size = viewSize.to!Vector2f;
			
			// Create a new buffer for the game
			// Maybe there is a way to simply resize it?
			if(game.buffer is null || game.buffer.getSize() != viewSize) {
				game.buffer = new RenderTexture();
				if(!game.buffer.create(viewSize.x, viewSize.y))
					throw new Exception(ERROR_BUFFER_CREATION_MESSAGE);
			}
		}
	}
	
	/++
	 + Draws the game buffer onto the game window
	 +/
	override void draw(RenderTarget target, RenderStates states) {
		// Render buffer to window
		_bufferSprite.setTexture(game.buffer.getTexture(), true);
		target.draw(_bufferSprite, states);
	}
	
	private {
		Sprite _bufferSprite;
	}
}