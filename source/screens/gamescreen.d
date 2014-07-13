import dsfml.graphics;

import game;
import input;


class GameScreen : Drawable {
	protected Game game;
	
	this(Game game) {
		this.game = game;
	}
	
	/++
	 + Updates the game by a delta rate.
	 +/
	abstract void cycle(in InputState input, in float delta);
	
	/++
	 + Draws the game on renderTarget.
	 +
	 + Note: This should be a const method, however due to the lack of
	 + constness in methods from the SFML wrapper, it is not marked as such.
	 +/
	abstract void draw(RenderTarget renderTarget, RenderStates states);
}