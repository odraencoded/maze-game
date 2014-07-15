import course;
import game;
import mazescreen;

/++
 + Moves between stages when each stage is completed.
 + Keeps track of how far the player is in a course.
 +/
class CourseContext {
	Game game;
	const Course course;
	int currentStage;
	
	void delegate(CourseContext) onCourseComplete;
	void delegate(CourseContext) onGameQuit;
	
	this(Game game, in Course course) {
		this.game = game;
		this.course = course;
	}
	
	void startPlaying() {
		// Reset progress
		currentStage = 0;
		
		// Setup maze screen
		auto mazeScreen = new MazeScreen(game);
		mazeScreen.onStageComplete = &onStageComplete;
		mazeScreen.onQuit = (MazeScreen screen) { onGameQuit(this); };
		
		// Set stage
		auto newStage = course.buildStage(currentStage);
		mazeScreen.setStage(newStage);
		
		// Schedule next screen
		game.nextScreen = mazeScreen;
	}
	
	void onStageComplete(MazeScreen screen) {
		// Change to the next stage
		currentStage++;
		if(currentStage < course.length) {
			auto stage = course.buildStage(currentStage);
			screen.setStage(stage);
		} else {
			onCourseComplete(this);
		}
	}
}