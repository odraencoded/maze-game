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
	ScalingMode scalingMode;
	
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
		auto viewRect = FloatRect(Vector2f(0, 0), windowSize.toVector2f);
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
			
			// Calculate the scale and the view size
			Vector2f scale;
			Vector2u viewSize;
			
			final switch(scalingMode) {
			case ScalingMode.None:
				viewSize = windowSize;
				scale = Vector2f(1, 1);
				break;
			case ScalingMode.PixelPerfect:
				// Get the smallest factor between the two sides, such that
				// neither dimension of game.size * factor is greater than
				// window.size
				Vector2f factor;
				factor.x = windowSize.x / cast(float)game.size.x;
				factor.y = windowSize.y / cast(float)game.size.y;
				float smallestFactor = min(factor.x, factor.y);
				float roundedFactor = cast(float)floor(smallestFactor);
				scale = Vector2f(roundedFactor, roundedFactor);
				
				viewSize.x = cast(uint)ceil(windowSize.x / scale.x);
				viewSize.y = cast(uint)ceil(windowSize.y / scale.y);
				break;
			}
			
			_bufferSprite.scale = scale;
			game.view.reset(FloatRect(Vector2f(0, 0), viewSize.toVector2f));
			
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

/++
 + Methods to scale the view.
 +/
enum ScalingMode {
	None, // Never scale
	PixelPerfect, // Scale by integer values
}