import course;
import game;
import mazescreen;
import signal;
import stage;

/++
 + Moves between stages when each stage is completed.
 + Keeps track of how far the player is in a course.
 +/
class CourseContext {
	Game game;
	const Course course;
	int currentStageIndex;
	Stage currentStageCopy;
	
	Signal!(CourseContext) onCourseComplete;
	Signal!(CourseContext) onGameQuit;
	
	this(Game game, in Course course) {
		this.game = game;
		this.course = course;
	}
	
	void startPlaying() {
		// Reset progress
		currentStageIndex = 0;
		
		// Setup maze screen
		auto mazeScreen = new MazeScreen(game);
		mazeScreen.onStageComplete ~= &onStageComplete;
		mazeScreen.onQuit ~= { onGameQuit(this); };
		mazeScreen.onRestart ~= {
			mazeScreen.setStage(currentStageCopy.clone());
		};
		
		// Set stage
		currentStageCopy = course.buildStage(currentStageIndex);
		mazeScreen.setStage(currentStageCopy.clone());
		
		// Schedule next screen
		game.nextScreen = mazeScreen;
	}
	
	void onStageComplete(MazeScreen mazeScreen) {
		// Change to the next stage
		currentStageIndex++;
		if(currentStageIndex < course.length) {
			currentStageCopy = course.buildStage(currentStageIndex);
			mazeScreen.setStage(currentStageCopy.clone());
		} else {
			onCourseComplete(this);
		}
	}
}