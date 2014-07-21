import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import course;
import coursecontext;
import game;
import gamescreen;
import input;
import menu;
import screens;
import utility;

enum MAZES_DIRECTORY = "mazes" ~ slash;

enum MENUSCREEN_WINDOW_TITLE = "Main Menu";

class MenuScreen : GameScreen {
	MenuContext menuContext;
	Menu mainMenu;
	
	this(Game game) {
		super(game);
		game.subtitle = MENUSCREEN_WINDOW_TITLE;
		
		menuContext = new MenuContext(game.assets);
		
		// Create main menu 
		// Play menu item
		auto playMenuItem = menuContext.createMenuItem("Play");
		playMenuItem.onActivate ~= &showPlayMenu;
		
		// Editor menu item
		auto editorMenuItem = menuContext.createMenuItem("Editor");
		editorMenuItem.onActivate ~= {
			auto editorScreen = new EditorScreen(game);
			editorScreen.onQuit ~= { game.nextScreen = this; };
			game.nextScreen = editorScreen;
		};
		
		// Exit menu item
		auto exitMenuItem = menuContext.createMenuItem("Exit");
		exitMenuItem.onActivate ~= { game.isRunning = false; };
		
		mainMenu = new Menu();
		mainMenu.items = [playMenuItem, editorMenuItem, null, exitMenuItem];
		
		menuContext.currentMenu = mainMenu;
	}
	
	override void cycle(in InputState input, in float delta) {
		menuContext.cycle(input, delta);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		renderTarget.draw(menuContext);
	}
	
	void showPlayMenu() {
		// Setup play course callback
		Course[MenuItem] menuItemsToCourses;
		auto playCourse = (MenuItem selectedMenuItem) {
			// Go to maze screen and play the course
			auto selectedCourse = menuItemsToCourses[selectedMenuItem];
			auto context = new CourseContext(game, selectedCourse);
			
			auto openMenuScreen = { game.nextScreen = this; };
			context.onGameQuit ~= openMenuScreen;
			context.onCourseComplete ~= openMenuScreen;
			context.startPlaying();
		};
		
		// Create course menu
		auto courseMenu = new Menu();
		
		// Search for courses and add them to course menu
		auto availableCourses = Course.SearchDirectory(MAZES_DIRECTORY);
		foreach(int i, Course aCourse; availableCourses) {
			auto aCourseTitle = aCourse.info.title;
			auto aCourseMenuItem = menuContext.createMenuItem(aCourseTitle);
			aCourseMenuItem.onActivate ~= playCourse;
			
			menuItemsToCourses[aCourseMenuItem] = aCourse;
			courseMenu.items ~= aCourseMenuItem;
		}
		
		// Add a space
		if(courseMenu.items.length > 0)
			courseMenu.items ~= null;
		
		// Add "go back" item
		auto goBackMenuItem = menuContext.createMenuItem("Return to main menu");
		courseMenu.items ~= goBackMenuItem;
		
		// Pressing esc on course menu or activating "go back"
		auto goBackToMainMenu = {
			menuContext.currentMenu = mainMenu;
			menuContext.selection = 0;
		};
		
		goBackMenuItem.onActivate ~= goBackToMainMenu;
		courseMenu.onCancel ~= goBackToMainMenu;
		
		// Set menu
		menuContext.currentMenu = courseMenu;
		menuContext.selection = 0;
	}
}