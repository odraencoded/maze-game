import dsfml.graphics;

public import game : Game;
public import input;
public import dsfml.graphics : RenderTarget, RenderStates;

class GameScreen : Drawable {
	protected Game game;
	
	this(Game game) {
		this.game = game;
	}
	
	/++
	 + Called when this screen is about to become the game's current screen.
	 +/
	void appear() { }
	
	/++
	 + Called when this screen is no longer the game's current screen.
	 +/
	void disappear() { }
	
	
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