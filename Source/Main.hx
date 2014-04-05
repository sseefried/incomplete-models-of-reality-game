package;


import flash.display.Sprite;
import flash.display.Graphics;
import flash.events.Event; // required for addEventListener
import flash.events.KeyboardEvent;
import flash.ui.Keyboard;

typedef Point = { x: Int, y: Int }

enum Block { Red; Blue; Space; }
enum Side { Top; Bottom; Left; Right;}
typedef Rect = { x1: Float, x2: Float, y1: Float, y2: Float};
typedef Collision = { left: Bool, right: Bool, top: Bool, bottom: Bool}

enum Pair<T,U> {
  Pair(v : T, u: U);
}

enum Option<T> {
  None;
  Some(v : T);
}


class Level {
	public static var BLOCKS_IN_ROW = 8;

	public var player: Point;
	public var blocks:  Array<Array<Block>>;

	public function new(s: String) {
		blocks = new Array();
		for (j in 0...BLOCKS_IN_ROW) {
			blocks[j] = new Array();
			for (i in 0...BLOCKS_IN_ROW) {
				var val = s.charAt((BLOCKS_IN_ROW - j - 1)*BLOCKS_IN_ROW+i);
				if (val == "R") {
					blocks[j][i] = Red;
				} else if (val == "B") {
					blocks[j][i] = Blue;
				} else {
					blocks[j][i] = Space;
				}
				if (val == "P") {
					player = { x: i, y: j};
				}
			}
		}
	}
}

class Main extends Sprite {

	// all as a fraction of a block width
	private static var ACCEL:Float = 0.01;
	private static var JUMP_VELOCITY:Float = 0.2;
	private static var RUN_VELOCITY:Float = 0.05;
	private static var PLAYER_WIDTH:Float = 0.25;
	private static var PLAYER_HEIGHT = 0.5;

  // Visible blocks
  private var visibleBlocks: Array<Block>;

	private var levelString: String =
    "        " +
    "        " +
    " BB B   " +
    "     B  " +
    "   P   R" +
    "      R " +
    "     R  " +
    "RRRRRRRR";

	// screen width/height
	private var w:Int;
	private var h:Int;

	// world width/height
	private var scale:Float;
	private var box:{ x: Float, y: Float, v: Float, movingLeft: Bool,
	                  movingRight: Bool, jumpPressed: Bool } ;

  private var level: Level;
  private var blockWidth: Float;

	public function new() {
		super();
    stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

    w = stage.stageWidth;
    h = stage.stageHeight;

    blockWidth = w/Level.BLOCKS_IN_ROW;
    level = new Level(levelString);
    box = { x: level.player.x*blockWidth, y: level.player.y*blockWidth,
    	         v: 0, movingRight: false,
               movingLeft: false, jumpPressed: false};
    visibleBlocks = [Red];


	}

	// world co-ordinates use left-handed co-ordinate system. x axis points right
	// y axis points up.
	private function drawBox(x: Float, y: Float, w: Float, h: Float, color: UInt) {
		graphics.beginFill(color);
		graphics.drawRect(x, this.h - (h+y), w, h);
	}

	private function overlaps(a: Rect, b: Rect): Option<Collision> {
		var right = b.x2 <= a.x1;
		var left  = a.x2 <= b.x1;
		var above = b.y2 <= a.y1;
		var below = a.y2 <= b.y1;

		var o = !(left || right || above || below);
    if (o) {
      return Some({ left:   a.x1 <= b.x2 && a.x1 > b.x1,
                    right:  a.x2 <= b.x2 && a.x2 > b.x1,
                    top:    a.y2 <= b.y2 && a.y2 > b.y1,
                    bottom: a.y1 <= b.y2 && a.y1 > b.y1 });
    } else {
      return None;
    }
	}

  private function rectEqual(a:Rect, b: Rect):Bool {
    return (a.x1 == b.x1 && a.y1 == b.y1 && a.x2 == b.x2 && a.y2 == b.y2);
  }

	//
	// For a given side of the player rectangle this returns
	// +Some(rect)+ where +rect+ is the rectangle of the block
	// the player collided with or None if the player did not
	// collide with any blocks
	//
	private function collision():Option<Pair<Rect, Collision>> {
		var b1 = { x1: box.x, y1: box.y,
			         x2: box.x + PLAYER_WIDTH*blockWidth,
			         y2: box.y + PLAYER_HEIGHT*blockWidth };
    for (j in 0...Level.BLOCKS_IN_ROW) {
    	for (i in 0...Level.BLOCKS_IN_ROW) {
    		var isBlock = (level.blocks[j][i] != Space);
    		if (isBlock) {
       		var b2 = { x1: i*blockWidth,
       			         y1: j*blockWidth,
			               x2: (i+1)*blockWidth,
			               y2: (j+1)*blockWidth  };
			    switch (overlaps(b1,b2)) {
            case Some(c):
  			    	return Some(Pair(b2,c));
            case None:
			    }
			  }
			}
		}
		return None;
	}

	private function updatePositionAndVelocity():Void {
		// Update position

    if (box.movingRight)  { box.x += RUN_VELOCITY*blockWidth; }
    if (box.movingLeft)   { box.x -= RUN_VELOCITY*blockWidth; }

    box.v = box.v - ACCEL*blockWidth;
    box.y = box.y + box.v;


	  switch (collision()) {
	  	case Some(Pair(r,c)):

        if (c.bottom) {
          box.y = r.y2;
	    	  box.v = 0;
	    	  if (box.jumpPressed) { box.v = JUMP_VELOCITY*blockWidth; }
        } else if (c.top) {
          box.y = r.y1 - PLAYER_HEIGHT*blockWidth;
          box.v = 0;
        }

      case None:
    }

    switch (collision()) {
      case Some(Pair(r,c)):
        if (c.right) {
          box.x = r.x1 - PLAYER_WIDTH*blockWidth;
        } else if (c.left) {
          box.x = r.x2;
        }
      case None:
    }

	}

	private function drawLevel() {
		for (j in 0...Level.BLOCKS_IN_ROW) {
			for (i in 0...Level.BLOCKS_IN_ROW) {
        // only draw block if it's visible
        if (visibleBlocks.lastIndexOf(level.blocks[j][i]) >= 0) {
  				var color = switch(level.blocks[j][i]) {
  						          case Red:   0xFF0000;
  						          case Blue:  0x0000FF;
  						          default:    0x000000;
               				};
          drawBox(i*blockWidth, j*blockWidth, blockWidth, blockWidth, color);
        }
			}
		}
	}

  private function toggleBlockVisibility(b: Block) {
    var i;
    if (i = visibleBlocks.lastIndexOf(b) >= 0) {
      visibleBlocks.remove(b);
    } else {
      visibleBlocks.push(b);
    }
  }

	// Events -- enabled with addEventListener. Requires flash.events.Event;
  private function onEnterFrame (event:Event):Void {
  	graphics.clear();
	  drawLevel();
  	updatePositionAndVelocity();
  	drawBox(box.x,box.y,PLAYER_WIDTH*blockWidth,PLAYER_HEIGHT*blockWidth, 0xFF00FF);


  }

  private function onKeyDown(event: KeyboardEvent):Void {
  	switch event.keyCode {
  		case Keyboard.RIGHT: box.movingRight = true;
  		case Keyboard.LEFT:  box.movingLeft  = true;
  		case Keyboard.UP:    box.jumpPressed = true;
      case Keyboard.R: toggleBlockVisibility(Red);
      case Keyboard.B: toggleBlockVisibility(Blue);
  	}
  }

  private function onKeyUp(event: KeyboardEvent):Void {
  	switch event.keyCode {
  		case Keyboard.RIGHT: box.movingRight = false;
  		case Keyboard.LEFT:  box.movingLeft  = false;
  		case Keyboard.UP:    box.jumpPressed = false;
  	}
  }



}