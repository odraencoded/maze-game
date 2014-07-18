import dsfml.graphics;

import geometry;

/++
 + Something that can be anchored to the screen.
 +/
interface Anchorable(T) {
	/++
	 + Returns the top left anchor point of this object
	 +/
	Vector2!T getTopLeft();
	
	/++
	 + Returns the bottom right anchor point of this object
	 +/
	Vector2!T getBottomRight();
	
	final Vector2!T getTopRight() {
		return Vector2!T(getTopLeft().x, 0);
	}
	
	final Vector2!T getBottomLeft() {
		return Vector2!T(0, getBottomRight().y);
	}
}

interface DisplayObject(T) : Drawable, Anchorable!T {
	alias Anchor = DisplayAnchor!T;
	
	final Anchor createAnchor() {
		return new Anchor(this);
	}
}

/++
 + Draws a display object in a corner of the view(screen).
 +/
class DisplayAnchor(T) : Drawable {
	DisplayObject!T  anchoredObject;
	
	Vector2!T margin;
	Side side;
	
	this(DisplayObject!T anchoredObject) {
		this.anchoredObject = anchoredObject;
	}
	
	void draw(RenderTarget renderTarget, RenderStates states) {
		// Get view anchor
		auto viewSize = renderTarget.view.size.toVector2!T;
		auto viewAnchor = side.getAnchor!T(0, 0, viewSize.x, viewSize.y);
		
		// Get object anchor
		immutable auto tl = anchoredObject.getTopLeft();
		immutable auto br = anchoredObject.getBottomRight();
		auto objAnchor = side.getAnchor!T(tl, br);
		
		// Get margin anchor
		auto marginAnchor = side.getAnchor!T(-margin, margin);
		
		auto finalAnchor = viewAnchor - objAnchor - marginAnchor;
		states.transform.translate(finalAnchor.x, finalAnchor.y);		
		renderTarget.draw(anchoredObject, states);
	}
}