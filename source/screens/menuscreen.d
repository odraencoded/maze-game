import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import course;
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
enum SELECTOR_Y = 16;

enum MENU_X = SELECTOR_X + 16;
enum MENU_Y = SELECTOR_Y - 6;

enum MENUSCREEN_WINDOW_TITLE = "Main Menu";

class MenuScreen : GameScreen {
	int selection;
	
	Course[] availableCourses;
	Text[] courseMenuItems;
	
	Font menuFont;
	
	Drawable selectorSprite;
	
	this(Game game) {
		super(game);
		game.subtitle = MENUSCREEN_WINDOW_TITLE;
		
		availableCourses = loadCourses(MAZES_DIRECTORY);
		
		menuFont = new Font();
		menuFont.loadFromFile(MENU_FONT_FILENAME);
		
		courseMenuItems = new Text[availableCourses.length];
		
		foreach(int i, Course aCourse; availableCourses) {
			Text newText = new Text();
			
			newText.setFont(menuFont);
			newText.setCharacterSize(MENU_TEXT_SIZE);
			newText.setColor(MENU_TEXT_COLOR);
			newText.setString(aCourse.info.title.to!dstring);
			newText.position = Vector2f(0, i * MENU_ITEM_HEIGHT);
			
			courseMenuItems[i] = newText;
		}
		
		selectorSprite = setupSelectorSprite();
	}
	
	override void cycle(in InputState input, in float delta) {
		int selectionChange;
		immutable auto systemInput = input.getSystemOffset(OnOffState.TurnedOn);
		if(systemInput.x || systemInput.y) {
			selectionChange = systemInput.y;
		} else {
			selectionChange = input.getOffset(OnOffState.TurnedOn).y;
		}
		
		selection += selectionChange + courseMenuItems.length;
		selection %= courseMenuItems.length;
		
		bool activate;
		activate = input.wasKeyTurnedOn(SystemKey.Return);
		activate |= input.wasTurnedOn(Command.Grab);
		
		if(activate) {
			game.course = availableCourses[selection];
			game.progress = 0;
			game.stage = game.course.buildStage(game.progress);
			
			auto mazeScreen = new MazeScreen(game);
			game.nextScreen = mazeScreen;
		}
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		RenderStates selectorStates;
		selectorStates.transform.translate(SELECTOR_X, SELECTOR_Y);
		
		renderTarget.draw(selectorSprite, selectorStates);
		
		RenderStates menuStates;
		menuStates.transform.translate(MENU_X, MENU_Y);
		menuStates.transform.translate(0, selection * MENU_ITEM_HEIGHT * -1);
		
		foreach(int i, Text aText; courseMenuItems) {
			renderTarget.draw(aText, menuStates);
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