import std.algorithm;
import std.traits;

/++
 + An event utility.
 + Name from GLib signals because "Event" would cause name conflics with SFML.
 +/
struct Signal(ARGS...) {
	alias fullHandlerType = void delegate(ARGS);
	fullHandlerType[] fullHandlers;
	
	/++
	 + Adds an event handler for this event.
	 +/
	void opOpAssign(string op : "~")(fullHandlerType value) pure {
		_addHandler(fullHandlers, value);
	}
	
	/++
	 + Removes an event handler for this event.
	 +/
	void removeHandler(fullHandlerType value) pure @safe {
		_removeHandler(fullHandlers, value);
	}
	
	/++
	 + If this event has more than one argument, simple handlers can
	 + also be used. These handles don't receive the arguments from the event.
	 +/
	static if(ARGS.length > 0) {
		alias simpleHandlerType = void delegate();
		simpleHandlerType[] simpleHandlers;
		
		
		/++
		 + Adds a simple event handler for this event.
		 +/
		void opOpAssign(string op : "~")(simpleHandlerType value) pure @safe {
			_addHandler(simpleHandlers, value);
		}
		
		/++
		 + Removes a simple event handler for this event.
		 +/
		void removeHandler(simpleHandlerType value) pure @safe {
			_removeHandler(simpleHandlers, value);
		}
	}
	
	/++
	 + Calls the event handlers.
	 +/
	void opCall(ParameterTypeTuple!fullHandlerType args) {
		foreach(fullHandlerType aFullHandler; fullHandlers) {
			aFullHandler(args);
		}
		
		static if(ARGS.length > 0) {
			foreach(simpleHandlerType aSimpleHandler; simpleHandlers) {
				aSimpleHandler();
			}
		}
	}
	
	static private void
	_addHandler(T)(ref T[] handlerList, T value) pure @safe {
		if(handlerList.canFind(value))
			throw new Exception("Event handler is already subscribed");
		
		handlerList ~= value;
	}
	
	static private void
	_removeHandler(T)(ref T[] handlerList, T value) pure @safe {
		auto index = handlerList.countUntil(value);
		if(index == -1)
			throw new Exception("Event handler is not subscribed");
		
		handlerList.remove(index);
	}
}