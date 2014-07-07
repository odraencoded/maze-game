import std.stdio;

import dsfml.graphics;

import game;
import geometry;

enum PLAYER_COLOR = Color.Green;
enum EXIT_COLOR = Color.Blue;
enum WALL_COLOR = Color.Black;
enum FIXED_WALL_COLOR = Color.Red;

public Stage LoadStage(string path) {
	Image bitmap = new Image();
	if(!bitmap.loadFromFile(path))
		throw new Exception(null);
	
	auto size = bitmap.getSize();
	Box bitmapFrame = {0, 0, size.x, size.y};
	Box stageFrame = {0, 0, (size.x + 1) / 2, (size.y + 1) / 2};
	bool[Point] checkedPoints;
	
	auto newStage = new Stage();
	
	for(uint x=0; x<size.x; x += 2) {
		for(uint y=0; y<size.y; y += 2) {
			Point position = Point(x / 2, y / 2);
			if(position in checkedPoints)
				continue;
			checkedPoints[position] = true;
			
			auto pixel = bitmap.getPixel(x, y);
			if(pixel == PLAYER_COLOR) {
				if(newStage.player)
					throw new Exception(null);
				
				newStage.player = new Pusher();
				newStage.player.position = position;
				
				Side neighbours = GetNeighbourPixels(x, y, bitmap, bitmapFrame);
				
				foreach(Side aCrossSide; CrossSides) {
					if(neighbours & aCrossSide) {
						newStage.player.facing = aCrossSide.getOpposite();
						break;
					}
				}
			} else if(pixel == EXIT_COLOR) {
				auto newExit = new Exit();
				newExit.position = position;
				newStage.exits ~= newExit;
			} else if(pixel == WALL_COLOR || pixel == FIXED_WALL_COLOR) {
				Point[] blocks, points;
				blocks ~= position;
				points ~= position;
				
				while(points.length > 0) {
					Point[] newPoints;
					
					foreach(Point point; points) {
						foreach(Side aCrossSide; CrossSides) {
							auto offset = aCrossSide.getOffset();
							auto checkPoint = point + offset;
							bool validCheck = stageFrame.contains(checkPoint) &&
							                  !(checkPoint in checkedPoints);
							if(validCheck) {
								auto farPoint = checkPoint * 2;
								auto nearPoint = farPoint - offset;
								auto nearColor = bitmap.getPixel(nearPoint.x,
								                                 nearPoint.y);
								auto farColor = bitmap.getPixel(farPoint.x,
								                                farPoint.y);
								
								if(nearColor == farColor &&
								   farColor == pixel) {
									blocks ~= checkPoint;
									newPoints ~= checkPoint;
									checkedPoints[checkPoint] = true;
								}
							}
						}
					}
					points = newPoints;
				}
				
				auto newWall = new Wall();
				newWall.blocks = blocks;
				if(pixel == FIXED_WALL_COLOR)
					newWall.isFixed = true;
				newStage.walls ~= newWall;
			}
		}
	}
	
	return newStage;
}

auto GetNeighbourPixels(uint x, uint y, Image bitmap, Box bitmapFrame) {
	Side result;
	auto center = bitmap.getPixel(x, y);
	
	for(int rx=-1; rx<=1; rx++) {
		for(int ry=-1; ry<=1; ry++) {
			int ax = rx + x, ay = ry + y;
			if(bitmapFrame.contains(Point(ax, ay))) {
			   if(bitmap.getPixel(ax, ay) == center) {
					result |= getDirection(Point(rx, ry));
			   }
			}
		}
	}
	
	return result;
}