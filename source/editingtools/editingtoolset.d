import dsfml.graphics;

import anchoring;
import assetcodes;
import game : GameAssets;
import geometry;
import tile;

/++
 + A set of tools.
 +/
class EditingToolSet : DisplayObject!int {
	enum TOOL_WIDTH = 16;
	enum TOOL_HEIGHT = 16;
	enum VERTICAL_PADDING = 0;
	enum BORDER_WIDTH = 1;
	
	GameAssets assets;
	
	EditingTool[] tools;
	EditingTool activeTool, highlightTool;
	VertexCache backgroundCache, iconCache, selectionCache;
	VertexCache highlightCache, selectionHighlightCache;
	
	uint width = 1;
	
	this(GameAssets assets) {
		this.assets = assets;
	}
	
	/++
	 + Returns the tool at point p
	 +/
	EditingTool getToolAt(Point p) {
		enum FULL_HEIGHT = TOOL_HEIGHT + VERTICAL_PADDING * 2 + BORDER_WIDTH;
		
		Point boxSize = getBottomRight();
		
		// Check if contained in the active tool sprite
		if(activeTool) {
			auto activeY = selectionCache.position.y;
			if(p.x >= -1 && p.y >= activeY - 1 && p.x < boxSize.x + 1) {
				if(p.y < activeY + TOOL_HEIGHT - BORDER_WIDTH + 1) {
					return activeTool;
				}
			}
		}
		
		// Check if contained in the toolbar
		if(p.x < boxSize.x && p.y < boxSize.y && p.x >= 0 && p.y >= 0) {
			if((p.y % FULL_HEIGHT) < FULL_HEIGHT - BORDER_WIDTH) {
				int highlightIndex = p.y / FULL_HEIGHT;
				return tools[highlightIndex];
			}
		}
		
		// Not found
		return null;
	}
	
	/++
	 + Sets the highlighted tool
	 +/
	void setHightlight(EditingTool tool) {
		highlightTool = tool;
		if(!(highlightTool is null)) {
			import std.algorithm : countUntil;
			int highlightIndex = tools.countUntil(highlightTool);
			highlightCache.position.y = getY(highlightIndex);
			selectionHighlightCache.position.y = highlightCache.position.y;
		}
	}
	
	/++
	 + Sets the highlighted tool
	 +/
	void setActive(EditingTool tool) {
		activeTool = tool;
		if(!(activeTool is null)) {
			import std.algorithm : countUntil;
			int activeIndex = tools.countUntil(activeTool);
			selectionCache.position.y = getY(activeIndex);
			selectionHighlightCache.position.y = selectionCache.position.y;
		}
	}
	
	int getY(int index) const pure {
		int result;
		
		int rowCount = index / width;
		// Rounding up. Too lazy to convert to float, get std.math, etc.
		if(tools.length % width > 0)
			rowCount += 1;
		
		result = TOOL_HEIGHT * rowCount;
		result += VERTICAL_PADDING * rowCount * 2;
		result += BORDER_WIDTH * rowCount;
		
		return result;
	}
	
	void updateCache() {
		// Cache background
		enum OUTLINE_COLOR = Color(0, 0, 0);
		enum FACE_COLOR = Color(190, 180, 160);
		enum SELECTION_FACE_COLOR = Color(231, 220, 193);
		enum BORDER_COLOR = Color(0, 0, 0, 64);
		enum HIGHLIGHT_COLOR = Color(255, 255, 255);
		
		auto boxSize = getBottomRight();
		
		auto outlineRect = FloatRect(-1, -1, boxSize.x + 2, boxSize.y + 2);
		auto outlineVertices = outlineRect.toVertexArray();
		outlineVertices.dye(OUTLINE_COLOR);
		
		auto faceRect = IntRect(0, 0, boxSize.x, boxSize.y);
		auto faceVertices = faceRect.toVertexArray();
		faceVertices.dye(FACE_COLOR);
		
		backgroundCache = new VertexCache();
		backgroundCache.add(outlineVertices);
		backgroundCache.add(faceVertices);
		
		// Cache selection sprite
		outlineRect = FloatRect(-2, -2, TOOL_WIDTH + 4, TOOL_HEIGHT + 4);
		outlineVertices = outlineRect.toVertexArray();
		outlineVertices.dye(OUTLINE_COLOR);
		
		faceRect = IntRect(-1, -1, TOOL_WIDTH + 2, TOOL_HEIGHT + 2);
		faceVertices = faceRect.toVertexArray();
		faceVertices.dye(SELECTION_FACE_COLOR);
		
		selectionCache = new VertexCache();
		selectionCache.add(outlineVertices);
		selectionCache.add(faceVertices);
		
		// Cache selection highlight sprite
		auto highlightVertices = faceRect.toVertexArray();
		highlightVertices.dye(HIGHLIGHT_COLOR);
		
		selectionHighlightCache = new VertexCache();
		selectionHighlightCache.add(highlightVertices);
		
		// Create highlight sprite
		faceRect = IntRect(0, 0, TOOL_WIDTH, TOOL_HEIGHT);
		highlightVertices = faceRect.toVertexArray();
		highlightVertices.dye(HIGHLIGHT_COLOR);
		
		highlightCache = new VertexCache();
		highlightCache.add(highlightVertices);
		
		// Cache icons, create border vertices
		Vertex[] borderVertices;
		
		iconCache = new VertexCache();
		iconCache.texture = &assets.textures[Asset.ToolsTexture];
		int toolY = -BORDER_WIDTH;
		foreach(int i, ref EditingTool tool; tools) {
			if(i > 0) {
				auto borderRect = IntRect(0, toolY, boxSize.x, BORDER_WIDTH);
				borderVertices ~= borderRect.toVertexArray();
			}
			toolY += BORDER_WIDTH + VERTICAL_PADDING;
			
			if(tool == activeTool)
				selectionCache.position.y = toolY;
			
			iconCache.add(tool.icon.vertices, Point(0, toolY));
			toolY += TOOL_HEIGHT + VERTICAL_PADDING;
		}
		
		borderVertices.dye(BORDER_COLOR);
		backgroundCache.add(borderVertices);
	}
	
	override void draw(RenderTarget renderTarget, RenderStates states) {
		if(backgroundCache is null)
			updateCache();
		
		// Draw background
		renderTarget.draw(backgroundCache, states);
		
		// Draw highlight sprite
		if(!(highlightTool is null) && !(highlightTool is activeTool)) {
			renderTarget.draw(highlightCache, states);
		}
		
		// Draw selection sprite
		if(!(activeTool is null)) {
			renderTarget.draw(selectionCache, states);
			
			// Draw highlight sprite
			if(highlightTool is activeTool) {
				renderTarget.draw(selectionHighlightCache, states);
			}
		}
		
		// Draw icons on top of everything
		renderTarget.draw(iconCache, states);
	}
	
	// Anchorable implementation
	Point getTopLeft() {
		return Point(0, 0);
	}
	
	Point getBottomRight() {
		Point size;
		size.x = width * TOOL_WIDTH;
		size.y = getY(tools.length) - BORDER_WIDTH;
		
		return size;
	}
	
	bool isUnderPoint(Point p) {
		immutable auto tl = getTopLeft();
		immutable auto br = getBottomRight();
		
		// Check if inside bar
		if(p.x >= tl.x && p.x < br.x && p.y >= tl.y && p.y < br.y)
			return true;
		
		// Check if contained in the active tool sprite
		if(activeTool) {
			auto activeY = selectionCache.position.y;
			if(p.x >= tl.x - 1 && p.y >= activeY - 1 && p.x < br.x + 1) {
				if(p.y < activeY + TOOL_HEIGHT - BORDER_WIDTH + 1) {
					return true;
				}
			}
		}
		
		return false;
	}
}

class EditingTool {
	const(Tile)* icon;
}