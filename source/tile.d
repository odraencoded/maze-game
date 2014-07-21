import dsfml.graphics;

class TextureMap {
	const(Tile)*[int] pieces;
	immutable Vector2i tileSize;
	
	/++
	 + Creates a texture map for tiles of size tileSize.
	 +/
	this(Vector2i tileSize = Vector2i(1, 1)) {
		this.tileSize = tileSize;
	}
	
	const(Tile)* opIndex(int key) const {
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
	void addPiece(in int key, in Tile* piece) {
		pieces[key] = piece;
	}
}

struct Tile {
	Vertex[] vertices = void;
	Vector2f origin;
	
	this(in IntRect rect, in Vector2f origin) immutable {
		vertices = rect.toTexturedVertices(origin).idup;
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

class VertexCache : Drawable {
	Vertex[] vertices;
	const(Texture)* texture;
	Vector2i position;
	
	void add(in Vertex[] newVertices, in Vector2i offset = Vector2i(0, 0)) {
		if(offset.x || offset.y) {
			auto movedVertices = new Vertex[newVertices.length];
			foreach(int i, const(Vertex) aVertex; newVertices) {
				movedVertices[i] = Vertex(
					aVertex.position + offset,
					aVertex.color,
					aVertex.texCoords);
			}
			vertices ~= movedVertices;
		} else {
			vertices ~= newVertices;
		}
	}
	
	void setColor(in Color color) pure {
		vertices.dye(color);
	}
	
	void draw(RenderTarget target, RenderStates states) {
		// Set texture
		if(texture)
			states.texture = *texture;
		
		// Move to position
		states.transform.translate(position.x, position.y);
		
		// Render
		target.draw(vertices, PrimitiveType.Quads, states);
	}
}

/++
 + Draws a tiled texture spanning over the whole view(screen).
 +/
class Backdrop : Drawable {
	const(Texture)* texture;
	Color color = Color.White;
	
	this(in Texture* texture) {
		this.texture = texture;
	}
	
	this(in Color color) {
		this.color = color;
	}
	
	void draw(RenderTarget target, RenderStates states) {
		if(texture)
			states.texture = *texture;
		Backdrop.render(target, states, color);
	}
	
	static void render(RenderTarget target, RenderStates states, Color color) {
		// Copy paste ALL THE THINGS!!!
		immutable auto viewSize = target.view.size;
		immutable auto viewCenter = target.view.center;
		immutable auto halfViewSize = viewSize / 2;
		
		immutable auto top    = viewCenter.y - halfViewSize.y;
		immutable auto left   = viewCenter.x - halfViewSize.x;
		immutable auto bottom = viewCenter.y + halfViewSize.y;
		immutable auto right  = viewCenter.x + halfViewSize.x;
		
		immutable auto topLeft     = Vector2f(left , top   );
		immutable auto topRight    = Vector2f(right, top   );
		immutable auto bottomRight = Vector2f(right, bottom);
		immutable auto bottomLeft  = Vector2f(left , bottom);
		
		immutable Vertex[] vertices = [
			Vertex(topLeft    , color, topLeft    ),
			Vertex(topRight   , color, topRight   ),
			Vertex(bottomRight, color, bottomRight),
			Vertex(bottomLeft , color, bottomLeft )
		];
		
		target.draw(vertices, PrimitiveType.Quads, states);
	}
}

/++
 + Returns a vertex rectangle with its texcoords mapped to box.
 + The top left of the rectangle is origin, the bottom right is the box size.
 +/
Vertex[]
toTexturedVertices(T)(in Rect!T box, in Vector2f origin = Vector2f(0, 0)) {
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


/++
 + Returns a vertex rectangle based on the box position and size.
 +/
Vertex[] toVertexArray(T)(in Rect!T box) {
	// Get the frame dimensions
	immutable auto top = box.top;
	immutable auto left = box.left;
	immutable auto bottom = box.top + box.height;
	immutable auto right = box.left + box.width;
	
	return [
		Vertex(Vector2f(left , top   )), Vertex(Vector2f(right, top   )),
		Vertex(Vector2f(right, bottom)), Vertex(Vector2f(left , bottom))
	];
}

void dye(ref Vertex[] vertices, in Color color) pure {
	foreach(ref Vertex aVertex; vertices)
		aVertex.color = color;
}