import dsfml.graphics;

class TextureMap {
	const(Tile)[int] pieces;
	immutable Vector2i tileSize;
	
	/++
	 + Creates a texture map for tiles of size tileSize.
	 +/
	this(Vector2i tileSize = Vector2i(1, 1)) {
		this.tileSize = tileSize;
	}
	
	ref const(Tile) opIndex(int key) const {
		return pieces[key];
	}
	
	/++
	 + Adds a tile of size 1x1 at position.
	 +/
	void addPiece(int key, Vector2i position,
	              in Vector2f origin = Vector2f(0, 0)) {
		immutable auto boundary = IntRect(position, Vector2i(1, 1));
		return addPiece(key, boundary, origin);
	}
	
	/++
	 + Adds a tile spanning through boundary.
	 +/
	void addPiece(in int key, in IntRect boundary,
	              in Vector2f origin = Vector2f(0, 0)) {
		// Scale values by tileSize
		immutable auto realBoundary = IntRect(
			boundary.left   * tileSize.x, boundary.top    * tileSize.y,
			boundary.width  * tileSize.x, boundary.height * tileSize.y);
		immutable auto realOrigin = Vector2f(
			origin.x * tileSize.x, origin.y * tileSize.y);
		
		auto newPiece = new immutable Tile(realBoundary, realOrigin);
		addPiece(key, newPiece);
	}
	
	/++
	 + Adds a tile with key key.
	 +/
	void addPiece(in int key, in Tile piece) {
		pieces[key] = piece;
	}
}

class Tile {
	Vertex[] vertices;
	Vector2f origin;
	
	this(in IntRect rect, in Vector2f origin) immutable {
		vertices = rect.toVertexArray(origin);
		this.origin = origin;
	}
}

class TileSprite : Drawable {
	const(Tile)* piece;
	const(Texture)* texture;
	Vector2i position;
	
	void draw(RenderTarget target, RenderStates states) {
		states.texture = *texture;
		states.transform.translate(position.x, position.y);
		target.draw(piece.vertices, PrimitiveType.Quads, states);
	}
}

immutable(Vertex)[] toVertexArray(T)(in Rect!T box, in Vector2f origin) {
	// Get the frame dimensions
	immutable auto tl = Vector2f(0        , 0         );
	immutable auto tr = Vector2f(box.width, 0         );
	immutable auto br = Vector2f(box.width, box.height);
	immutable auto bl = Vector2f(0        , box.height);
	
	// The frame top left
	immutable auto p = Vector2f(box.left, box.top);
	
	// The texture coords are the box coordinates,
	// The vertex positions are the box size offset by origin
	return [
		Vertex(tl - origin, p + tl), Vertex(tr - origin, p + tr),
		Vertex(br - origin, p + br), Vertex(bl - origin, p + bl), 
	];
}