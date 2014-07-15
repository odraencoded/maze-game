import std.conv;
import std.math;

import dsfml.system.vector2;

import utility;

alias Point = Vector2!int;

// Vector utilities
U length(T : Vector2!U, U)(const T vector) {
	return (vector.x.abs.sqrt + vector.y.abs.sqrt).pow(2);
}

T normalize(T : Vector2!U, U)(const T vector) {
	auto l = length(vector);
	return l > 0 ? vector / l : T(0, 0);
}

Vector2!TTo toVector(TFrom, TTo)(in Vector2!TFrom vector) {
	return Vector2!TTo(vector.x.to!TTo(), vector.y.to!TTo());
}

Vector2f toVector2f(T)(in Vector2!T vector) {
	return vector.toVector!(T, float)();
}

T round(T: Vector2!U, U)(const T vector) {
	return T(vector.x.nearbyint, vector.y.nearbyint);
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