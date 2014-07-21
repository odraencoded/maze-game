import std.file;
import std.json;
import std.path;
import std.string;

import dsfml.graphics;
import yaml;

import game;
import stage;
import geometry;
import moreyaml;
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
	
	/++
	 + Loads a course from a file
	 +/
	static Course FromDisk(in string filename) {
		// get absolute filename
		auto absoluteFilename = filename.absolutePath;
		
		// Load course info
		yaml.Node root = yaml.Loader(absoluteFilename).load();
		
		auto result = new Course();
		
		// Get title
		auto fileTitle = filename.baseName.stripExtension;
		result.info.title = root.tryGet("title", fileTitle);
		
		// Get URL
		result.info.url = root.tryGet!string("url", null);
		
		// Get author list
		auto authorNodes = root.tryGet!(yaml.Node[])("authors", null);
		if(authorNodes) {
			foreach(yaml.Node anAuthorNode; authorNodes) {
				if(anAuthorNode.isType!string)
					result.info.authors ~= anAuthorNode.as!string;
			}
		}
		
		// Get stages
		auto stageNodes = root.tryGet!(yaml.Node[])("stages", []);
		auto baseDirectory = absoluteFilename.dirName;
		foreach(yaml.Node aStageNode; stageNodes) {
			string aFilename;
			if(!aStageNode.tryGet(aFilename))
				continue;
				
			auto normalizedPath = buildNormalizedPath(baseDirectory, aFilename);
			
			// Really need a way to store metadata
			auto newMetadata = new StageInfo();
			newMetadata.title = aFilename.baseName.stripExtension;
			
			auto newStageEntry = new StageEntry();
			newStageEntry.generator = new SimpleStageGenerator(normalizedPath);
			newStageEntry.metadata = newMetadata;
			
			result.stages ~= newStageEntry;
		}
		
		if(result.stages.length == 0) {
			throw new Exception(
				"Course \"" ~ filename  ~ "\" does not have stages."
			);
		}
		
		return result;
	}
	
	/++
	 + Searches a directory for course definition files
	 +/
	static Course[] SearchDirectory(in string directory) {
		// Search directories for valid files
		string[] courseFilenames;
		foreach(DirEntry anEntry; dirEntries(directory, SpanMode.breadth)) {
			if(anEntry.isFile && isValidCourseFile(anEntry.name)) {
				courseFilenames ~= anEntry.name;
			}
		}
		
		// Load courses
		Course[] result;
		foreach(string aFilename; courseFilenames)
			result ~= Course.FromDisk(aFilename);
		
		return result;
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

/++
 + Whether a given file is a valid course file.
 +/
bool isValidCourseFile(in string filename) {
	enum COURSE_EXTENSION = ".course";
	return filename.extension == COURSE_EXTENSION;
}

/++
 + Generates a stage. Duh.
 +/
interface StageGenerator {
	Stage buildStage() const;
}

/++
 + Creates a using Stage.FromDisk
 +/
class SimpleStageGenerator : StageGenerator {
	string filename;
	
	this(string filename) {
		this.filename = filename;
	}
	
	Stage buildStage() const {
		return Stage.FromDisk(filename);
	}
}