package;


import flash.display.Sprite;
import flash.display.Graphics;
import flash.events.Event; // required for addEventListener
import flash.events.KeyboardEvent;
import flash.ui.Keyboard;

import box2D.collision.shapes.B2PolygonShape;
import box2D.common.math.B2Vec2;
import box2D.dynamics.B2Body;
import box2D.dynamics.B2BodyDef;
import box2D.dynamics.B2FixtureDef;
import box2D.dynamics.B2Fixture;
import box2D.dynamics.B2World;
import box2D.collision.shapes.B2ShapeType;
import box2D.dynamics.B2DebugDraw;
import box2D.dynamics.contacts.B2Contact;


/*
 * Co-ordinate system.
 *
 * Nearly all functions that take co-ordindate values will take values in
 * "world co-ordinates", not in screen co-ordinates.
 *
 * Most 2D graphics libraries (flash.display.Graphics included)
 * use a co-ordinate system where the x-axis goes from left-to-right
 * and the y-axis goes from top-to-bottom. I'm going to call this a
 * screen co-ordinate system.
 *
 * This is not the Cartesian co-ordinate system I learned in high school, where
 * the y axis goes from bottom-to-top, so like one of those annoying
 * people who has to invert the Y-axis in a first person shooter game,
 * I am going to transform from virtual co-ordinates in a Cartesian system
 * to the screen co-ordinate system.
 *
 * Each unit of this system will be a "block" in the game. The world
 * is Level.BLOCKS_IN_ROW wide and high. (The world is sqaure, not rectangular.)
 *
 * We are using Box2D as the physics system. Box2D performs its calculations
 * using values that correspond to physical SI units. Thus, we set each
 * block to be 1m x 1m i.e. 1 square metre. This means that we can equally well
 * say that the player is moving at 2 blocks per second or 2 m/s.
 *
 */

typedef UserData = { isSensor: Bool }

typedef Point = { x: Int, y: Int }

// Blocks are either Red, Blue or a space.
enum Block { Red; Blue; Space; }

enum Pair<T,U> {
  Pair(fst : T, snd: U);
}

enum Option<T> {
  None;
  Some(v : T);
}


class Level {
	public static var BLOCKS_IN_ROW = 8;

	public var initPlayerPos: Point;
	public var blocks:  Array<Array<Block>>;

  //
  // The new function parses an array of strings [ss] that defines the level. The string must have
  // exactly BLOCK_IN_ROW^2 characters, and each of those characters must be an ['R'], ['B'], [' ']
  // or ['P'] character.
  //
  // Each element of [ss] defines a row of the level. The array is traversed in reverse order so
  // that the last element defines the bottom row, the penultimate element defines the second row,
  // etc. This is done so that one may draw the level using ASCII art in the source code. e.g.
  //
  //  var ss = [ "        "
  //           , "        "
  //           , " BB B   "
  //           , "     B  "
  //           , "   P   R"
  //           , "      R "
  //           , "     R  "
  //           , "RRRRRRRR" ];
  //
  //
	public function new(ss: Array<String>) {
		blocks = new Array();
		for (j in 0...BLOCKS_IN_ROW) {
			blocks[j] = new Array();
			for (i in 0...BLOCKS_IN_ROW) {
				var val = ss[(BLOCKS_IN_ROW - 1) - j].charAt(i);
				if (val == "R") {
					blocks[j][i] = Red;
				} else if (val == "B") {
					blocks[j][i] = Blue;
				} else {
					blocks[j][i] = Space;
				}
				if (val == "P") {
					initPlayerPos = { x: i, y: j};
				}
			}
		}
	}
}

typedef Player = { movingLeft: Bool, movingRight: Bool, jumping: Bool, body: B2Body,
                   contacts: Int }

class PlayerContactListener extends box2D.dynamics.B2ContactListener {

  private var player: Player;

  public function new(p: Player) {
    super();
    player = p;
  }

  public override function beginContact(contact:B2Contact):Void {
    var ud: UserData = contact.getFixtureB().getUserData();
    if (ud != null && ud.isSensor) {
      player.contacts += 1;
    }
  }

  public override function endContact(contact:B2Contact):Void {
    var ud: UserData = contact.getFixtureB().getUserData();
    if (ud != null && ud.isSensor) {
      player.contacts -= 1;
    }
  }

}

class Main extends Sprite {

	// all as a fraction of a block
	private static var JUMP_VELOCITY:Float = 4.5;
	private static var RUN_VELOCITY:Float = 2;
	private static var PLAYER_WIDTH:Float = 0.25;
	private static var PLAYER_HEIGHT = 0.5;

  private static var BLOCK_WIDTH: Float = 1.0;
  private static var STEPS_PER_SECOND = 30;  // Box2D steps per second.

  // The block sorts that are currently visible. e.g. [ Red ]
  private var visibleBlocks: Array<Block>;

	private var levelString: Array<String> =
    [ "        "
    , "        "
    , " BB B   "
    , "     B  "
    , "   P   R"
    , "      R "
    , "     R  "
    , "RRRRRRRR" ];

	// screen width/height. These values are set to mirror those from project.xml
	private var w:Int;
	private var h:Int;

  private var physics_width: Float; // For Box2D. In metres
  // multiply screen co-ordinates by [scale] to get world co-ordinates.
  private var scale: Float;
  private var world: B2World; // Box2D world.


	private var player: Player;

  private var level: Level;
  private var blockWidth: Float;

  private function setupDebugDraw(world: B2World, scale: Float) {
    var physicsDebug = new Sprite ();
    addChild (physicsDebug);


    var debugDraw = new B2DebugDraw ();
    debugDraw.setSprite (physicsDebug);
    debugDraw.setDrawScale (scale);
    debugDraw.setFlags (B2DebugDraw.e_shapeBit);
    world.setDebugDraw (debugDraw);

  }

	public function new() {
		super();

    var i: Int;
    var j: Int;

    stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

    w = stage.stageWidth;
    h = stage.stageHeight;

    level = new Level(levelString);

    physics_width = Level.BLOCKS_IN_ROW;
    scale = w/(Level.BLOCKS_IN_ROW*BLOCK_WIDTH);

    world = new B2World(new B2Vec2(0, -10.0), false);

    setupDebugDraw(world, scale);

    visibleBlocks = [Red];

    // Create level blocks
    for (j in 0...Level.BLOCKS_IN_ROW) {
      for (i in 0...Level.BLOCKS_IN_ROW) {
        if (level.blocks[j][i] != Space) {
          createBox(i, j, BLOCK_WIDTH, BLOCK_WIDTH);
        }
      }
    }

    var p: Point = level.initPlayerPos;
    // create player

    player = { movingRight: false, movingLeft: false, jumping: false, body: null,
               contacts: 0 };

    var playerBody: B2Body = createPlayer(p.x, p.y);

    player.body = playerBody;

	}

  private function createPlayer(i:Int, j:Int) {
    var bodyDefinition = new B2BodyDef ();
    // In Box2D the position of an object is it's centre so we need to add on BLOCK_WIDTH/2
    // to the position.

    bodyDefinition.position.set ((i + width/2)*BLOCK_WIDTH, (j + height/2)*BLOCK_WIDTH);

    bodyDefinition.type = B2Body.b2_dynamicBody;
    bodyDefinition.fixedRotation = true;

    var body = world.createBody (bodyDefinition);

    var halfWidth = PLAYER_WIDTH*BLOCK_WIDTH/2;
    var halfHeight = PLAYER_HEIGHT*BLOCK_WIDTH/2;

    var polygon = new B2PolygonShape();
    polygon.setAsBox(halfWidth, halfHeight);

    var sensor = new B2PolygonShape();
    sensor.setAsOrientedBox(0.5*halfWidth, 0.1*BLOCK_WIDTH, new B2Vec2(0, -halfHeight), 0);

    var fixtureDefinition = new B2FixtureDef ();
    fixtureDefinition.shape = polygon;
    fixtureDefinition.friction = 0.0;

    body.createFixture(fixtureDefinition);

    fixtureDefinition = new B2FixtureDef();
    fixtureDefinition.shape = sensor;
    fixtureDefinition.isSensor = true;

    var sensorFixture: B2Fixture = body.createFixture(fixtureDefinition);
    sensorFixture.SetUserData({ isSensor: true });

    world.setContactListener(new PlayerContactListener(player));

    return body;

  }


  private function createBox (i:Int, j:Int, width:Float, height:Float):B2Body {

    var bodyDefinition = new B2BodyDef ();
    // In Box2D the position of an object is it's centre so we need to add on BLOCK_WIDTH/2
    // to the position.

    bodyDefinition.position.set ((i + width/2)*BLOCK_WIDTH, (j + height/2)*BLOCK_WIDTH);

    var polygon = new B2PolygonShape();
    polygon.setAsBox(width*BLOCK_WIDTH/2, height*BLOCK_WIDTH/2);

    var fixtureDefinition = new B2FixtureDef ();
    fixtureDefinition.shape = polygon;
    fixtureDefinition.friction = 0.0;

    var body = world.createBody (bodyDefinition);
    body.createFixture (fixtureDefinition);
    return body;
  }

  //
  // Draws a rectangle defined by bottom-left corner ([x],[y]), width [w] and height [h]
  // and color [color] (Color is an RGB value encoded as 32-bit integer. e.g. 0x00FF00FF)
  // is full red and blue, no green. i.e. magenta.
  //
  // [x], [y], [w], [h] are all in world co-ordinates.
  //
	private function drawRect(x: Float, y: Float, w: Float, h: Float, color: UInt) {
		graphics.beginFill(color);
		graphics.drawRect(x*scale, this.h - (h+y)*scale, w*scale, h*scale);
	}

	private function updatePositionAndVelocity():Void {
    var p = player.body.getPosition();
    if (player.jumping && player.contacts > 0) {

      player.body.setLinearVelocity(new B2Vec2(0, JUMP_VELOCITY*BLOCK_WIDTH));
    }

    var v: Float = 0;
    if (player.movingLeft) {
      v -= RUN_VELOCITY*BLOCK_WIDTH;
    }

    if (player.movingRight) {
      v += RUN_VELOCITY*BLOCK_WIDTH;
    }

    var lv = player.body.getLinearVelocity();
    player.body.setLinearVelocity(new B2Vec2(v, lv.y));
    // HACK. Bump up player by just smallest amount
    player.body.setPosition(new B2Vec2(p.x, p.y + 0.01));

	}

	private function drawLevel() {
    graphics.clear();
		for (j in 0...Level.BLOCKS_IN_ROW) {
			for (i in 0...Level.BLOCKS_IN_ROW) {
        // only draw block if it's visible
        if (visibleBlocks.lastIndexOf(level.blocks[j][i]) >= 0) {
  				var color = switch(level.blocks[j][i]) {
  						          case Red:   0xFF0000;
  						          case Blue:  0x0000FF;
  						          default:    0x000000;
               				};
          drawRect(i*BLOCK_WIDTH, j*BLOCK_WIDTH, BLOCK_WIDTH, BLOCK_WIDTH, color);
        }
			}
		}

    // Draw player
    var p = player.body.getPosition();
    var x = p.x - PLAYER_WIDTH*BLOCK_WIDTH/2;
    var y = p.y - PLAYER_HEIGHT*BLOCK_WIDTH/2;
    drawRect(x, y, PLAYER_WIDTH*BLOCK_WIDTH, PLAYER_HEIGHT*BLOCK_WIDTH, 0x00FF00FF);

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
    world.step (1 / STEPS_PER_SECOND, 10, 10);
    world.clearForces();
//    world.drawDebugData();
    drawLevel();
  	updatePositionAndVelocity();
    // draw the player
  }

  private function onKeyDown(event: KeyboardEvent):Void {
  	switch event.keyCode {
  		case Keyboard.RIGHT: player.movingRight = true;
  		case Keyboard.LEFT:  player.movingLeft  = true;
  		case Keyboard.UP:    player.jumping = true;
      case Keyboard.R: toggleBlockVisibility(Red);
      case Keyboard.B: toggleBlockVisibility(Blue);
  	}
  }

  private function onKeyUp(event: KeyboardEvent):Void {
  	switch event.keyCode {
  		case Keyboard.RIGHT: player.movingRight = false;
  		case Keyboard.LEFT:  player.movingLeft  = false;
  		case Keyboard.UP:    player.jumping = false;
  	}
  }



}