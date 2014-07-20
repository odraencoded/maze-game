import inputstate;
import signal;

enum dchar LOWEST_PRINTABLE = ' '; // # 32
enum dchar HIGHEST_PRINTABLE = '~'; // # 126
enum dchar BACKSPACE_CHARACTER = '\b';
enum dchar RETURN_CHARACTER = '\r';
enum dchar ESCAPE_CHARACTER = 27;

/++
 + Utility class to manage receiving text from TextReceived events.
 +/
class TextReceiver {
	dstring currentText, savedText;
	
	Signal!(TextReceiver) onChange, onReturn, onEscape;
	
	this(dstring text) {
		savedText = currentText = text;
	}
	
	void cycle(in InputState input) {
		// Nothing to do...
		if(input.newText.length == 0)
			return;
		
		bool changed = false;
		foreach(dchar newChar; input.newText) {
			if(newChar >= LOWEST_PRINTABLE && newChar <= HIGHEST_PRINTABLE) {
				currentText ~= newChar;
				changed = true;
			} else if(newChar == BACKSPACE_CHARACTER) {
				if(currentText.length > 0)
					currentText.length--;
				changed = true;
			} else if(newChar == RETURN_CHARACTER) {
				onReturn(this);
			} else if(newChar == ESCAPE_CHARACTER) {
				onEscape(this);
			}
		}
		if(changed)
			onChange(this);
	}
	
	/++
	 + Saves the current text so that the next edits can be cancelled
	 +/
	void saveText() {
		savedText = currentText;
	}
	
	/++
	 + Resets current text to saved text
	 +/
	void cancelEdits() { currentText = savedText; }
}

