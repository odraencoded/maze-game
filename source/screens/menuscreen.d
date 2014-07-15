import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import course;
import coursecontext;
import game;
import gamescreen;
import input;
import mazescreen;
import menu;
import utility;

enum MAZES_DIRECTORY = "mazes" ~ slash;

enum MENUSCREEN_WINDOW_TITLE = "Main Menu";

class MenuScreen : GameScreen {
	MenuContext menuContext;
	
	Course[] availableCourses;
	
	this(Game game) {
		super(game);
		game.subtitle = MENUSCREEN_WINDOW_TITLE;
		
		menuContext = new MenuContext();
		
		availableCourses = loadCourses(MAZES_DIRECTORY);
		auto courseTitles = new string[availableCourses.length];
		foreach(int i, Course aCourse; availableCourses) {
			courseTitles[i] = aCourse.info.title;
		}
		
		auto courseMenu = new Menu();
		auto courseMenuItems = menuContext.createMenuItems(courseTitles);
		
		auto playCourse = (MenuItem item) {
			// Go to maze screen and play the course
			auto selectedCourse = availableCourses[menuContext.selection];
			auto context = new CourseContext(game, selectedCourse);
			context.onGameQuit = context.onCourseComplete = (CourseContext ctx){
				game.nextScreen = this;
			};
			context.startPlaying();
		};
		
		foreach(MenuItem anItem; courseMenuItems) {
			anItem.onActivate = playCourse;
		}
		
		if(courseMenuItems.length > 0)
			courseMenuItems ~= null;
		
		courseMenuItems ~= menuContext.createMenuItems(["Go back"]);
		courseMenu.items = courseMenuItems;
		
		auto mainMenuTexts = ["Play", "Exit"];
		auto mainMenu = new Menu();
		mainMenu.items = menuContext.createMenuItems(mainMenuTexts);
		
		// Play menu item
		mainMenu.items[0].onActivate = (MenuItem item) {
			menuContext.currentMenu = courseMenu;
			menuContext.selection = 0;
		};
		
		// Exit menu item
		mainMenu.items[1].onActivate = (MenuItem item) {
			game.isRunning = false;
		};
		
		// Pressing esc on course menu or activating "go back"
		courseMenu.items[$ - 1].onActivate = (MenuItem item) {
			menuContext.currentMenu = mainMenu;
			menuContext.selection = 0;
		};
		
		courseMenu.onCancel = (Menu menu) {
			menuContext.currentMenu = mainMenu;
			menuContext.selection = 0;
		};
		
		menuContext.currentMenu = mainMenu;
	}
	
	override void cycle(in InputState input, in float delta) {
		menuContext.cycle(input, delta);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		renderTarget.draw(menuContext);
	}
}