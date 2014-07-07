import std.stdio;

import dsfml.graphics;

import game;

enum PLAYER_COLOR = Color.Red;
enum EXIT_COLOR = Color.Blue;
enum WALL_COLOR = Color.Black;

public Stage LoadStage(string path) {
	Image bitmap = new Image();
	if(!bitmap.loadFromFile(path))
		throw new Exception(null);
	
	auto size = bitmap.getSize();
	bool[] checkedPoints = new bool[(size.x + 1) / 2 * (size.y + 1) / 2];
	
	auto newStage = new Stage();
	
	for(uint x=0; x<size.x; x += 2) {
		for(uint y=0; y<size.y; y += 2) {
			auto pixel = bitmap.getPixel(x, y);
			
			Point position = Point(x / 2, y / 2);
			
			checkedPoints[position.y * (size.y + 1) / 2 + position.x] = true;
			
			if(pixel == PLAYER_COLOR) {
				if(newStage.player)
					throw new Exception(null);
				
				newStage.player = new Pusher();
				newStage.player.position = position;
				
				Side neighbours = GetNeighbourPixels(x, y, bitmap);
				Side[] validSides = [Side.Top, Side.Right, Side.Bottom, Side.Left];
				
				foreach(Side aValidSide; validSides) {
					if(neighbours & aValidSide) {
						newStage.player.facing = getOpposite(aValidSide);
						break;
					}
				}
			}
		}
	}
	
	return newStage;
}

auto GetNeighbourPixels(uint x, uint y, Image bitmap) {
	Side result;
	auto center = bitmap.getPixel(x, y);
	auto size = bitmap.getSize();
	
	for(int rx=-1; rx<=1; rx++) {
		for(int ry=-1; ry<=1; ry++) {
			int ax = rx + x, ay = ry + y;
			if(ax >= 0 && ay >= 0 &&
			   ax < size.x && ay < size.y) {
			   if(bitmap.getPixel(ax, ay) == center) {
					result |= getDirection(Point(rx, ry));
			   }
			}
		}
	}
	
	return result;
}