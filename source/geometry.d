import std.math;
import dsfml.system.vector2;

alias Point = Vector2!int;

/**
 * Returns a Side value equivalent to the offset.
 * The offset X goes from Left to Right, Y from Top to Bottom
 * If both are axes are non-zero a diagonal such as TopRight is returned.
 */
Side getDirection(Point offset) {
	if(offset.x) offset.x /= abs(offset.x);
	if(offset.y) offset.y /= abs(offset.y);
	return directionTable[offset];
}

/**
 * Values for 2D directions. Each bit represents an unique direction.
 *
 * A value such as Top | Right isn't equivalent to TopRight.
 * TopRight is one diagonal, Top | Right are two separate directions.
 */
enum Side {
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
 * Using a Side with multiple bits set is an error. 
 */
Point getOffset(Side side) {
	return offsetTable[side];
}

/**
 * Returns a value which is the opposite Side of the input.
 * e.g getOpposite(Side.Right) == Side.Left
 */
Side getOpposite(Side side) {
	return oppositeTable[side];
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
private immutable Side[Point] directionTable;
private immutable Point[Side] offsetTable;
private immutable Side[Side] oppositeTable;

static this() {
	// Initialize direction table
	directionTable[Point( 0,  0)] = Side.None;
	directionTable[Point( 0, -1)] = Side.Top;
	directionTable[Point( 1, -1)] = Side.TopRight;
	directionTable[Point( 1,  0)] = Side.Right;
	directionTable[Point( 1,  1)] = Side.BottomRight;
	directionTable[Point( 0,  1)] = Side.Bottom;
	directionTable[Point(-1,  1)] = Side.BottomLeft;
	directionTable[Point(-1,  0)] = Side.Left;
	directionTable[Point(-1, -1)] = Side.TopLeft;
	
	// Initialize offsetTable, which is the inverse of the directionTable
	foreach(Point offset, Side side; directionTable)
		offsetTable[side] = offset;
	
	// Initialize oppositeTable
	foreach(Point offset, Side side; directionTable)
		oppositeTable[side] = getDirection(offset * -1);
}