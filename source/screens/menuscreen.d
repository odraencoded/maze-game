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
		
		menuContext = new MenuContext(game);
		
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
		
		// Editor menu item
		auto optionsMenuItem = menuContext.createMenuItem("Options");
		optionsMenuItem.onActivate ~= &showOptionsMenu;
		
		// Exit menu item
		auto exitMenuItem = menuContext.createMenuItem("Exit Game");
		exitMenuItem.onActivate ~= { game.isRunning = false; };
		
		mainMenu = new Menu();
		mainMenu.items = [
			playMenuItem, editorMenuItem, optionsMenuItem,
			null, exitMenuItem
		];
		
		menuContext.currentMenu = mainMenu;
	}
	
	override void appear() {
		game.subtitle = MENUSCREEN_WINDOW_TITLE;
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
	
	void showOptionsMenu() {
		import scaling;
		
		// Create options menu
		auto optionsMenu = new Menu();
		
		// Create control bindings menu items
		struct CommandName {
			Command command;
			dstring name;
		}
		
		CommandName[] bindingOrder = [
			CommandName(Command.GoUp         , "Go Up"         ),
			CommandName(Command.GoRight      , "Go Right"      ),
			CommandName(Command.GoDown       , "Go Down"       ),
			CommandName(Command.GoLeft       , "Go Left"       ),
			CommandName(Command.Grab         , "Grab"          ),
			CommandName(Command.Camera       , "Camera"        ),
			CommandName(Command.CyclePrevious, "Cycle Previous"),
			CommandName(Command.CycleNext    , "Cycle Next"    ),
			CommandName(Command.Restart      , "Restart"       ),
		];
		
		foreach(CommandName aBindingName; bindingOrder) {
			auto bindingText = menuContext.createText();
			auto bindingMenuItem = new KeyBindingMenuItem(
				bindingText, menuContext, this.game.bindings,
				aBindingName.command, aBindingName.name ~ ": "
			);
			optionsMenu.items ~= bindingMenuItem;
		}
		
		// Adding a space
		optionsMenu.items ~= null;
		
		// Add a scaling mode menu item
		auto scalingText = menuContext.createText();
		auto scalingMenuItem = new ChoiceMenuItem!ScalingMode(
			scalingText, "Scaling Mode: "
		);
		
		alias ScalingChoice = scalingMenuItem.Choice;
		scalingMenuItem.choices = [
			ScalingChoice("No Scaling", ScalingMode.None),
			ScalingChoice("Pixel Perfect", ScalingMode.PixelPerfect),
		];
		scalingMenuItem.selectedChoice = this.game.resizer.scalingMode;
		scalingMenuItem.onChoose ~= {
			this.game.resizer.scalingMode = scalingMenuItem.selectedChoice;
		};
		optionsMenu.items ~= scalingMenuItem;
		
		// Add a fullscreen mode menu item
		auto fullscreenText = menuContext.createText();
		auto fullscreenMenuItem = new ChoiceMenuItem!bool(fullscreenText);
		
		alias FullscreenChoice = fullscreenMenuItem.Choice;
		fullscreenMenuItem.choices = [
			FullscreenChoice("Windowed", false),
			FullscreenChoice("Fullscreen", true),
		];
		fullscreenMenuItem.selectedChoice = this.game.isFullscreen;
		fullscreenMenuItem.onChoose ~= {
			if(fullscreenMenuItem.selectedChoice) {
				this.game.goFullscreen();
			} else {
				this.game.goWindowed();
			}
		};
		optionsMenu.items ~= fullscreenMenuItem;
		
		// Add "go back" item
		auto goBackMenuItem = menuContext.createMenuItem("Return to main menu");
		optionsMenu.items ~= [null, goBackMenuItem];
		
		// Pressing esc on course menu or activating "go back"
		auto goBackToMainMenu = {
			this.game.saveSettings(GAME_SETTINGS_FILENAME);
			menuContext.currentMenu = mainMenu;
			menuContext.selection = 0;
		};
		
		goBackMenuItem.onActivate ~= goBackToMainMenu;
		optionsMenu.onCancel ~= goBackToMainMenu;
		
		// Set menu
		menuContext.currentMenu = optionsMenu;
		menuContext.selection = 0;
	}
}