import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import course;
import coursecontext;
import game;
import gamescreen;
import input;
import mazescreen;
import utility;

enum MAZES_DIRECTORY = "mazes" ~ slash;

// Must not forget I got this from of http://tenbytwenty.com/
enum MENU_FONT_FILENAME = "assets" ~ slash ~ "text" ~ slash ~ "Munro.ttf";
enum MENU_TEXT_SIZE = 20;
enum MENU_TEXT_COLOR = Color.White;

enum MENU_ITEM_HEIGHT = 25;

enum SELECTOR_X = 16;
enum SELECTOR_Y = 64;

enum MENU_X = SELECTOR_X + 16;
enum MENU_Y = SELECTOR_Y - 6;

enum MENUSCREEN_WINDOW_TITLE = "Main Menu";

enum PLAY_OPTION_INDEX = 0;
enum EXIT_OPTION_INDEX = 1;

class MenuScreen : GameScreen {
	int selection;
	
	Font menuFont;
	
	Course[] availableCourses;
	Text[] mainMenu, courseMenu, currentMenu;
	
	Drawable selectorSprite;
	
	this(Game game) {
		super(game);
		game.subtitle = MENUSCREEN_WINDOW_TITLE;
		
		menuFont = new Font();
		menuFont.loadFromFile(MENU_FONT_FILENAME);
		
		selectorSprite = setupSelectorSprite();
		
		availableCourses = loadCourses(MAZES_DIRECTORY);
		auto courseTitles = new string[availableCourses.length];
		foreach(int i, Course aCourse; availableCourses) {
			courseTitles[i] = aCourse.info.title;
		}
		
		courseMenu = createTexts(courseTitles);
		if(courseMenu.length > 0)
			courseMenu ~= null;
		
		courseMenu ~= createTexts(["Go back"]);
		
		auto mainMenuTexts = ["Play", "Exit"];
		mainMenu = createTexts(mainMenuTexts);
		
		currentMenu = mainMenu;
	}
	
	private Text[] createTexts(string[] strings) {
		Text[] result = new Text[strings.length];
		
		foreach(int i, string aString; strings) {
			Text newText = new Text();
			
			newText.setFont(menuFont);
			newText.setCharacterSize(MENU_TEXT_SIZE);
			newText.setColor(MENU_TEXT_COLOR);
			newText.setString(aString.to!dstring);
			
			result[i] = newText;
		}
		return result;
	}
	
	override void cycle(in InputState input, in float delta) {
		// Get whether the selection changed
		int selectionChange;
		immutable auto systemInput = input.getSystemOffset(OnOffState.TurnedOn);
		if(systemInput.x || systemInput.y) {
			// system input(arrow keys) have precedence
			selectionChange = systemInput.y;
		} else {
			selectionChange = input.getOffset(OnOffState.TurnedOn).y;
		}
		
		// Go to the next item that is not null
		do {
			selection += selectionChange + currentMenu.length;
			selection %= currentMenu.length;
		} while(currentMenu[selection] is null);
		
		// Whether the menu item has been activated
		bool activate;
		activate = input.wasKeyTurnedOn(SystemKey.Return);
		activate |= input.wasTurnedOn(Command.Grab);
		
		if(activate) {
			if(currentMenu == mainMenu) {
				if(selection == PLAY_OPTION_INDEX) {
					// Go to courses menu
					currentMenu = courseMenu;
					selection = 0;
					
				} else if(selection == EXIT_OPTION_INDEX) {
					// Exit the game
					game.isRunning = false;
				}
			} else {
				if(selection == courseMenu.length - 1) {
					// This is the go back option
					currentMenu = mainMenu;
					selection = 0;
				} else {
					// Go to maze screen and play the course
					auto selectedCourse = availableCourses[selection];
					auto context = new CourseContext(game, selectedCourse);
					context.onCourseComplete = (CourseContext ctx){
						game.nextScreen = this;
					};
					context.startPlaying();
				}
			}
		}
		
		// Checking whether the player cancelled the action
		bool cancel;
		cancel = input.wasKeyTurnedOn(SystemKey.Escape);
		if(cancel) {
			if(currentMenu == courseMenu) {
				// Same as go back option
				currentMenu = mainMenu;
				selection = 0;
			}
		}
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		RenderStates selectorStates;
		selectorStates.transform.translate(SELECTOR_X, SELECTOR_Y);
		
		renderTarget.draw(selectorSprite, selectorStates);
		
		RenderStates menuStates;
		menuStates.transform.translate(MENU_X, MENU_Y);
		menuStates.transform.translate(0, selection * MENU_ITEM_HEIGHT * -1);
		
		foreach(Text aText; currentMenu) {
			if(aText) {
				renderTarget.draw(aText, menuStates);
			}
			menuStates.transform.translate(0, MENU_ITEM_HEIGHT);
		}
	}
}

private auto setupSelectorSprite() {
	VertexArray selector = new VertexArray(PrimitiveType.Triangles, 3);
	selector[0].position = Vector2f(2, 2);
	selector[1].position = Vector2f(2, 14);
	selector[2].position = Vector2f(12, 8);
	for(int i=0; i<3; i++) selector[i].color = Color.White;
	return selector;
}