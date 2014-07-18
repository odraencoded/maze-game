import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import game;
import input;
import menu;
import signal;
import tile;
import utility;

// Must not forget I got this from of http://tenbytwenty.com/
enum MENU_TEXT_SIZE = 20;
enum MENU_TEXT_COLOR = Color.White;

enum MENU_ITEM_HEIGHT = 25;

enum SELECTOR_X = 16;
enum SELECTOR_Y = 64;

enum MENU_X = SELECTOR_X + 16;
enum MENU_Y = SELECTOR_Y - 5;

class MenuContext : Drawable {
	int selection;
	
	Menu currentMenu;
	Font menuFont;
	
	TileSprite selectorSprite;
	
	this(GameAssets assets) {
		menuFont = assets.menuFont;
		
		selectorSprite = new TileSprite();
		selectorSprite.texture = &assets.textures[Asset.SymbolTexture];
		
		auto symbolMap = assets.maps[Asset.SymbolMap];
		selectorSprite.piece = symbolMap[SymbolMapKeys.MenuSelector];
	}
	
	MenuItem[] createMenuItems(string[] strings) {
		MenuItem[] result = new MenuItem[strings.length];
		
		foreach(int i, string aString; strings) {
			result[i] = createMenuItem(aString);
		}
		return result;
	}
	
	MenuItem createMenuItem(string aString) {
		auto newText = new Text();
		
		newText.setFont(menuFont);
		newText.setCharacterSize(MENU_TEXT_SIZE);
		newText.setColor(MENU_TEXT_COLOR);
		newText.setString(aString.to!dstring);
		
		auto newItem = new MenuItem();
		newItem.text = newText;
		return newItem;
		
	}
	
	void cycle(in InputState input, in float delta) {
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
			selection += selectionChange + currentMenu.items.length;
			selection %= currentMenu.items.length;
		} while(currentMenu.items[selection] is null);
		
		// Whether the menu item has been activated
		bool activate;
		activate = input.wasKeyTurnedOn(SystemKey.Return);
		activate |= input.wasTurnedOn(Command.Grab);
		
		if(activate) {
			auto selectedItem = currentMenu.items[selection];
			selectedItem.onActivate(selectedItem);
		}
		
		// Checking whether the player cancelled the action
		bool cancel;
		cancel = input.wasKeyTurnedOn(SystemKey.Escape);
		if(cancel) {
			currentMenu.onCancel(currentMenu);
		}
	}
	
	void draw(RenderTarget renderTarget, RenderStates states) {
		RenderStates selectorStates;
		selectorStates.transform.translate(SELECTOR_X, SELECTOR_Y);
		
		renderTarget.draw(selectorSprite, selectorStates);
		
		RenderStates menuStates;
		menuStates.transform.translate(MENU_X, MENU_Y);
		menuStates.transform.translate(0, selection * MENU_ITEM_HEIGHT * -1);
		
		foreach(MenuItem anItem; currentMenu.items) {
			if(anItem) {
				renderTarget.draw(anItem.text, menuStates);
			}
			menuStates.transform.translate(0, MENU_ITEM_HEIGHT);
		}
	}
}

class Menu {
	MenuItem[] items;
	Signal!(Menu) onCancel;
}

class MenuItem {
	Text text;
	Signal!(MenuItem) onActivate;
}