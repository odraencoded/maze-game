import geometry;

enum Asset {
	PusherMap = "pusher",
	PusherTexture = "pusher",
	
	GroundMap = "ground",
	GroundTexture = "ground",
	
	WallMap = "wall",
	WallBackgroundTexture = "wall-background",
	WallForegroundTexture = "wall-foreground",
	WallOutlineTexture = "wall-outline",
	
	SymbolMap = "symbol",
	SymbolTexture = "symbol",
	
	ToolsMap = "tools",
	ToolsTexture = "tools",
	
	BlueprintBG = "blueprint-bg",
}

enum PusherMapKeys {
	PusherUp, PusherLeft, PusherRight, PusherDown,
}

enum GroundMapKeys {
	Exit,
}

enum WallMapKeys {
	TopLeftSide   , TopSide   , TopRightSide   ,
	LeftSide      , Fill      , RightSide      ,
	BottomLeftSide, BottomSide, BottomRightSide,
	
	InnerTopLeftCorner   , InnerTopRightCorner   ,
	InnerBottomLeftCorner, InnerBottomRightCorner,
}

enum SymbolMapKeys {
	MenuSelector, SquareCursor
}

enum ToolsMapKeys {
	SelectionTool, TrashTool,
	WallTool, PusherTool, ExitTool, 
}

static immutable int[int] PUSHER_FACING_TO_KEY_TABLE;

static this() {
	PUSHER_FACING_TO_KEY_TABLE[Side.Up   ] = PusherMapKeys.PusherUp;
	PUSHER_FACING_TO_KEY_TABLE[Side.Down ] = PusherMapKeys.PusherDown;
	PUSHER_FACING_TO_KEY_TABLE[Side.Left ] = PusherMapKeys.PusherLeft;
	PUSHER_FACING_TO_KEY_TABLE[Side.Right] = PusherMapKeys.PusherRight;
}