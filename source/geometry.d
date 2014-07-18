import std.conv;
import std.math;

import dsfml.system.vector2;

import utility;

alias Point = Vector2!int;

// Vector utilities
U length(T : Vector2!U, U)(in T vector) {
	return (vector.x.abs.sqrt + vector.y.abs.sqrt).pow(2);
}

T normalize(T : Vector2!U, U)(in T vector) {
	auto l = length(vector);
	return l > 0 ? vector / l : T(0, 0);
}

Vector2!TTo toVector2(TTo, TFrom)(in Vector2!TFrom vector) {
	return Vector2!TTo(vector.x.to!TTo(), vector.y.to!TTo());
}

Vector2f toVector2f(T)(in Vector2!T vector) {
	return vector.toVector2!(float, T)();
}

T round(T: Vector2!U, U)(in T vector) {
	return T(vector.x.nearbyint, vector.y.nearbyint);
}

/++
 + Returns a point based on side.
 + The return vector has an X equal to left, "center", and right
 + depending on whether the horizontal flags are Side.Left, Side.None or 
 + Side.Left | Side.Right, and Side.Right respectively.
 + Same thing for vertical.
 + e.g Side.None | Side.Vertical return the center point.
 +     Side.Left | Side.Top returns top-left.
 +/
Vector2!T getAnchor(T)(
	in Side side, in T left, in T top, in T right, in T bottom
) pure @safe {
	Vector2!T result;
	
	immutable auto horizontal = side & Side.Horizontal;
	if(horizontal == Side.Left) result.x = left;
	else if(horizontal == Side.Right) result.x = right;
	else result.x = left + (right - left) / 2;
	
	immutable auto vertical = side & Side.Vertical;
	if(vertical == Side.Top) result.y = top;
	else if(vertical == Side.Bottom) result.y = bottom;
	else result.y = top + (bottom - top) / 2;
	
	return result;
}

auto getAnchor(T)(
	in Side side, in Vector2!T topLeft, in Vector2!T bottomRight
) pure @safe {
	return getAnchor(side, topLeft.x, topLeft.y, bottomRight.x, bottomRight.y);
}

/++ 
 + Returns at which point in a grid a vector would be.
 + Equivalent to dividing vector by gridSize, rounding it down and
 + converting to a point
 +/
Point getGridPoint(T: Vector2!U, U)(in T vector, in real gridSize) pure @safe {
	immutable int x = floor(vector.x / gridSize).to!int;
	immutable int y = floor(vector.y / gridSize).to!int;
	
	return Point(x, y);
}

/**
 * Returns a Side value equivalent to the offset.
 * The offset X goes from Left to Right, Y from Top to Bottom
 * If both are axes are non-zero a diagonal such as TopRight is returned.
 */
Side getDirection(scope Point offset) pure {
	if(offset.x) offset.x /= abs(offset.x);
	if(offset.y) offset.y /= abs(offset.y);
	return DIRECTION_TABLE[offset];
}

/**
 * Values for 2D directions. Each bit represents an unique direction.
 *
 * A value such as Top | Right isn't equivalent to TopRight.
 * TopRight is one diagonal, Top | Right are two separate directions.
 */
enum Side : ubyte {
	None        = 0,
	Top         = 1,
	TopRight    = 2,
	Right       = 4,
	BottomRight = 8,
	Bottom      = 16,
	BottomLeft  = 32,
	Left        = 64,
	TopLeft     = 128,
	
	Up = Top,
	Down = Bottom,
	
	Vertical = Top | Bottom,
	Horizontal = Left | Right,
	Diagonal = TopRight | TopLeft | BottomRight | BottomLeft,
	
	All = Vertical | Horizontal | Diagonal,
	
	// More useless enum values, yay!
	TopAndLeft     = Top    | Left,
	TopAndRight    = Top    | Right,
	BottomAndLeft  = Bottom | Left,
	BottomAndRight = Bottom | Right,
}

/**
 * Returns a Point representing an offset towards a direction.
 *
 * P + getOffset(Side.Left) equals a point to the Left of P.
 * This follows the same coordinate system as getDirection,
 * So that side == getDirection(getOffset(side))
 *
 */
Point getOffset(in Side side) pure @safe {
	Point offset;
	foreach(int flag; side.getFlags())
		offset += OFFSET_TABLE[flag];
	return offset;
}

/**
 * Returns a value which is the opposite Side of the input.
 * e.g getOpposite(Side.Right) == Side.Left
 */
Side getOpposite(in Side side) pure {
	return cast(Side)(side << 4 | side >> 4);
}

/**
 * A bounding box structure.
 */
pure struct Box {
	int left, top, width, height;
	
	bool contains(Point p) const {
		return p.x >= left && p.x < left + width &&
		       p.y >= top && p.y < top + height;
	}
	
	int area() const @property {
		return width * height;
	}
}

/++
 + A point that moves
 +/
struct MovingPoint {
	Point current, previous;
	
	this(Point position = Point(0, 0)) {
		current = previous = position;
	}
	
	/++
	 + Returns the difference between its current position and
	 + its previous position.
	 +/
	Point movement() const pure nothrow @safe @property {
		return current - previous;
	}
	
	/++
	 + Sets a new current position
	 +/
	void move(Point newPosition) pure nothrow @safe {
		previous = current;
		current = newPosition;
	}
	
	/++
	 + Whether it has moved between now and then.
	 +/
	bool hasMoved() const pure nothrow @safe @property {
		return previous != current;
	}
}

public immutable Side[] CrossSides = [
	Side.Top, Side.Right, Side.Bottom, Side.Left
];

private immutable Side[Point] DIRECTION_TABLE;
private immutable Point[int] OFFSET_TABLE;

static this() {
	// Initialize direction table
	DIRECTION_TABLE[Point( 0,  0)] = Side.None;
	DIRECTION_TABLE[Point( 0, -1)] = Side.Top;
	DIRECTION_TABLE[Point( 1, -1)] = Side.TopRight;
	DIRECTION_TABLE[Point( 1,  0)] = Side.Right;
	DIRECTION_TABLE[Point( 1,  1)] = Side.BottomRight;
	DIRECTION_TABLE[Point( 0,  1)] = Side.Bottom;
	DIRECTION_TABLE[Point(-1,  1)] = Side.BottomLeft;
	DIRECTION_TABLE[Point(-1,  0)] = Side.Left;
	DIRECTION_TABLE[Point(-1, -1)] = Side.TopLeft;
	
	// Initialize OFFSET_TABLE, which is the inverse of the DIRECTION_TABLE
	foreach(Point offset, Side side; DIRECTION_TABLE)
		OFFSET_TABLE[side] = offset;
}