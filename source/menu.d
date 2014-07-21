import std.conv;
import std.path: slash = dirSeparator;

import dsfml.graphics;

import assetcodes;
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
	bool lockSelector;
	
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
		auto newText = createText(aString);
		
		auto newItem = new MenuItem();
		newItem.text = newText;
		return newItem;
	}
	
	Text createText(string aString = "") {
		auto newText = new Text();
		
		newText.setFont(menuFont);
		newText.setCharacterSize(MENU_TEXT_SIZE);
		newText.setColor(MENU_TEXT_COLOR);
		newText.setString(aString.to!dstring);
		
		return newText;
	}
	
	void cycle(in InputState input, in float delta) {
		if(!lockSelector)
			cycleSelector(input, delta);
		
		// Cycle items
		foreach(MenuItem anItem; currentMenu.items) {
			if(anItem)
				anItem.cycle(input, delta);
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
	
	/++
	 + Gets which item is currently selected.
	 +/
	ref MenuItem selectedItem() pure @property {
		return currentMenu.items[selection];
	}
	
	/++
	 + Sets selection to a given item
	 +/
	void selectedItem(MenuItem item) @property {
		import std.algorithm;
		
		immutable auto newIndex = currentMenu.items.countUntil(item);
		if(newIndex != -1)
			selection = newIndex;
	}
	
	void cycleSelector(in InputState input, in float delta) {
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
}

class Menu {
	MenuItem[] items;
	Signal!(Menu) onCancel;
}

class MenuItem {
	Text text;
	Signal!(MenuItem) onActivate;
	void cycle(in InputState input, in float delta) {}
}

/++
 + A menu item that can edit texts.
 +/
class TextEntryMenuItem : MenuItem {
	import textreceiver;
	
	MenuContext menuContext;
	TextReceiver textReceiver;
	dstring prefix;
	bool typingText, instantSwitchBackGuard;
	
	enum CARET_FLASHING_RATE = 0.8f; // 800ms
	float caredAnimation = 0;
	
	this(
		Text text,
		MenuContext context,
		dstring prefix = "",
		dstring current = ""
	) {
		this.text = text;
		this.menuContext = context;
		this.prefix = prefix;
		this.textReceiver = new TextReceiver(current);
		refreshText();
		
		onActivate ~= &beginTextEntry;
		
		textReceiver.onChange ~= {
			caredAnimation = 0;
			refreshText();
		};
		
		textReceiver.onEscape ~= {
			textReceiver.cancelEdits();
			exitTextEntry();
		};
		
		textReceiver.onReturn ~= {
			if(instantSwitchBackGuard == false) {
				textReceiver.saveText();
				exitTextEntry();
			}
		};
	}
	
	override void cycle(in InputState input, in float delta) {
		if(!typingText)
			return;
		
		// Update text received
		textReceiver.cycle(input);
		
		// Update caret animation
		caredAnimation = (caredAnimation + delta) % CARET_FLASHING_RATE;
		
		refreshText();
		
		// Unlock instant switch back guard
		instantSwitchBackGuard = false;
	}
	
	/++
	 + Gets the text input into the menu item
	 +/
	dstring typedText() @property {
		return textReceiver.currentText;
	}
	
	void refreshText() {
		// Refresh text graphic
		if(caredAnimation > CARET_FLASHING_RATE / 2)
			text.setString(this.prefix ~ textReceiver.currentText ~ "_");
		else
			text.setString(this.prefix ~ textReceiver.currentText);
	}
	
	/++
	 + Enter typing text mode
	 +/
	void beginTextEntry() {
		// This is set so that if the enter key was pressed to activate
		// this item, it won't cause for the item to instantly return
		// on the the onReturn signal
		instantSwitchBackGuard = true;
		menuContext.lockSelector = true;
		typingText = true;
	}
	
	/++
	 + Exits typing text mode
	 +/
	void exitTextEntry() {
		typingText = false;
		menuContext.lockSelector = false;
		caredAnimation = 0;
		refreshText();
	}
}

/++
 + A menu item that cycles through multiple options.
 +/
class ChoiceMenuItem(T) : MenuItem {
	Signal!(ChoiceMenuItem) onChoose;
	
	dstring prefix;
	
	struct Choice {
		dstring text;
		T value;
	}
	
	Choice[] choices;
	
	/++
	 + The index of the current selected choice.
	 + Returns -1 if selection is invalid.
	 +/
	@property {
		int selectedIndex() {
			return _selectedIndex;
		}
		
		void selectedIndex(int newIndex) {
			_selectedIndex = newIndex;
			refreshText();
			onChoose(this);
		}
	}
	
	/++
	 + Getter and setter for the selected value.
	 + Sets selectedIndex to -1 if input is not amongst valid choices.
	 +/
	@property {
		T selectedChoice(){
			return choices[selectedIndex].value;
		}
	
		void selectedChoice(T newChoice) {
			import std.algorithm;
			
			selectedIndex = countUntil!"a.value == b"(choices, newChoice);
		}
	}
	
	this(Text text, dstring prefix) {
		this.text = text;
		this.prefix = prefix;
		refreshText();
		
		onActivate ~= &cycleThroughChoices;
	}
	
	void refreshText() {
		// Refresh text graphic
		if(selectedIndex >= 0) {
			auto choiceText = choices[selectedIndex % $].text;
			text.setString(this.prefix ~ choiceText);
		} else {
			text.setString(this.prefix ~ "?");
		}
	}
	
	/++
	 + Switch to the next choice.
	 +/
	void cycleThroughChoices() {
		if(choices.length > 0) {
			_selectedIndex = (_selectedIndex + 1) % choices.length;
		} else {
			_selectedIndex = -1;
		}
		
		onChoose(this);
		refreshText();
	}
	
private:
	int _selectedIndex = -1;
}