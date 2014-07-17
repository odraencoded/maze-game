import std.file;
import std.json;
import std.string;

import dsfml.graphics;

import game;
import stage;
import geometry;
import json;
import stageobject;
import utility;

enum PUSHER_COLOR = Color.Green;
enum EXIT_COLOR = Color.Blue;
enum WALL_COLOR = Color.Black;
enum FIXED_WALL_COLOR = Color.Red;


/**
 * A course is a collection of stages.
 */
class Course {
	CourseInfo info;
	StageEntry[] stages;
	
	this() {
		info = new CourseInfo();
	}
	
	/**
	 * The number of stages in this course.
	 */
	int length() const @property {
		return stages.length;
	}
	
	/**
	 * Creates the selected stage and returns it.
	 */
	Stage buildStage(int index) const {
		auto stageEntry = stages[index];
		auto stage = stageEntry.generator.buildStage();
		stage.metadata = &stageEntry.metadata;
		return stage;
	}
}

/++
 + Metadata of a Course.
 +/
class CourseInfo {
	string title;
	string[] authors;
	string url;
}

/++
 + Represents a stage in a course.
 +/
class StageEntry {
	StageGenerator generator;
	StageInfo metadata;
}

/**
 * Loads a course from a directory
 */
Course loadCourse(in string directory) {
	// It takes a lot of stuff to read a directory :/
	import std.stdio;
	import std.regex;
	import std.path;
	import std.array;
	import std.conv;
	
	/**
	 * The test format is(after the extension is stripped)
	 * Numbers, dash, underscore or a space separator and then the stage title.
	 * e.g: 02-My A-Maze-Ing Maze
	 * The title part isn't required.
	 */
	enum stageFileRegex = regex(r"^(\d+)([-_ ](.+))?");
	enum INDEX_CAPTURE_INDEX = 1;
	enum STAGE_NAME_CAPTURE_INDEX = 3;
	
	struct StageFileEntry {
		int index;
		string title;
		string path;
	}
	StageFileEntry[] stageFiles;
	
	enum COURSE_INFO_FILENAME = "course";
	string courseInfoPath = null;
	
	foreach(string path; dirEntries(directory, SpanMode.shallow))
	{
		auto filename = baseName(stripExtension(path));
		auto matches = match(filename, stageFileRegex);
		if(matches) {
			StageFileEntry newEntry;
			newEntry.path = path;
			
			// Get the index of this stage
			auto indexString = matches.captures[INDEX_CAPTURE_INDEX];
			newEntry.index = indexString.to!int();
			
			// Set the stage title from the filename
			newEntry.title = matches.captures[STAGE_NAME_CAPTURE_INDEX];
			
			// Find the position for this entry in the array
			int i;
			for(i = 0; i < stageFiles.length; i++) {
				if(newEntry.index <= stageFiles[i].index)
					break;
			}
			stageFiles.insertInPlace(i, newEntry);
		} else if(filename.cmp(COURSE_INFO_FILENAME) == 0) {
			// Set path to file containing data about the course
			courseInfoPath = path;
		}
	}
	
	// Create a generator for each stage
	Course result = new Course();
	foreach(StageFileEntry aFileEntry; stageFiles) {
		auto newStageEntry = new StageEntry();
		newStageEntry.generator = new BitmapStageLoader(aFileEntry.path);
		
		auto newMetadata = new StageInfo();
		newMetadata.title = aFileEntry.title;
		newStageEntry.metadata = newMetadata;
		
		result.stages ~= newStageEntry;
	}
	
	// Load course info if an info file is found
	if(!(courseInfoPath is null))
		result.info = loadCourseInfo(courseInfoPath);
	
	// Use directory name as fallback course title
	if(result.info.title.length == 0) {
		result.info.title = baseName(directory);
	}
	
	return result;
}

/**
 * Attempts to load a directory subdirectories as courses.
 */
Course[] loadCourses(in string directory) {
	string[] subdirs;
	foreach(DirEntry anEntry; dirEntries(directory, SpanMode.shallow)) {
		if(anEntry.isDir)
			subdirs ~= anEntry.name;
	}
	
	Course[] result = new Course[subdirs.length];
	foreach(int i, string aSubdir; subdirs)
		result[i] = loadCourse(aSubdir);
	
	return result;
}

/**
 * Generates a stage. Duh.
 */
interface StageGenerator {
	Stage buildStage() const;
}

/**
 * Creates a stage from a bitmap file.
 */
class BitmapStageLoader : StageGenerator {
	string path;
	
	this(string path) {
		this.path = path;
	}
	
	Stage buildStage() const {
		return loadBitmapStage(path);
	}
}

/**
 * Parses a bitmap file into a stage.
 */
public Stage loadBitmapStage(in string path) {
	enum BITMAP_STAGE_OPEN_ERROR_MESSAGE = "Couldn't open bitmap stage file";
	
	// Load stage bitmap from file
	Image bitmap = new Image();
	if(!bitmap.loadFromFile(path))
		throw new Exception(BITMAP_STAGE_OPEN_ERROR_MESSAGE);
	
	return loadBitmapStage(bitmap);
}

public Stage loadBitmapStage(scope Image bitmap) {
	auto size = bitmap.getSize();
	Box bitmapFrame = {0, 0, size.x, size.y};
	Box stageFrame = {0, 0, (size.x + 1) / 2, (size.y + 1) / 2};
	bool[Point] checkedPoints;
	
	auto newStage = new Stage();
	
	for(uint i=0; i < stageFrame.area; i++) {
		uint x = i % stageFrame.width * 2;
		uint y = i / stageFrame.width * 2;
		
		Point position = Point(x / 2, y / 2);
		if(position in checkedPoints)
			continue;
		checkedPoints[position] = true;
		
		auto pixel = bitmap.getPixel(x, y);
		if(pixel == PUSHER_COLOR) {
			auto newPusher = new Pusher();
			newPusher.position = position;
			
			Side neighbours = GetNeighbourPixels(x, y, bitmap, bitmapFrame);
			
			foreach(Side aCrossSide; CrossSides) {
				if(neighbours & aCrossSide) {
					newPusher.facing = aCrossSide.getOpposite();
					break;
				}
			}
			
			newStage.pushers ~= newPusher;
		} else if(pixel == EXIT_COLOR) {
			auto newExit = new Exit();
			newExit.position = position;
			newStage.exits ~= newExit;
		} else if(pixel == WALL_COLOR || pixel == FIXED_WALL_COLOR) {
			Point[] points;
			points ~= position;
			
			Side[Point] blocks;
			blocks[position] = Side.None;
			
			while(points.length > 0) {
				Point[] newPoints;
				
				foreach(Point point; points) {
					foreach(Side aCrossSide; CrossSides) {
						auto offset = aCrossSide.getOffset();
						auto checkPoint = point + offset;
						
						if(!stageFrame.contains(checkPoint))
							continue;
						
						Point nearPoint, farPoint;
						Color nearColor, farColor;
						
						farPoint = checkPoint * 2;
						nearPoint = farPoint - offset;
						
						nearColor = bitmap.getPixel(nearPoint.x, nearPoint.y);
						farColor = bitmap.getPixel(farPoint.x, farPoint.y);
						
						if(nearColor == farColor && farColor == pixel) {
							if(point in blocks)
								blocks[point] |= aCrossSide;
							else
								blocks[point] = aCrossSide;
							
							if(checkPoint in blocks)
								blocks[checkPoint] |= aCrossSide.getOpposite();
							else
								blocks[checkPoint] = aCrossSide.getOpposite();
							
							if(!(checkPoint in checkedPoints)) {
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
			newWall.grabbable = pixel != FIXED_WALL_COLOR;
			newStage.walls ~= newWall;
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

CourseInfo loadCourseInfo(in string path) {
	CourseInfo result = new CourseInfo();
	
	auto json = parseJSON(readText(path));
	JSONValue[string] root;
	
	if(json.getJsonValue(root)) {
		root.getJsonValue("title", result.title);
		root.getJsonValues("authors", result.authors);
		root.getJsonValue("url", result.url);
	}
	
	return result;
}