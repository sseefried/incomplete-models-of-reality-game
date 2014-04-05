# A game about incomplete models of reality

## What the game is about

This game was directly inspired by thinking about the limitations of our
five senses and our ability to think. Simply by looking at the history
of human thought one can see that we had many mistaken beliefs that were
later corrected by experiment and observation.

I wanted to create a game which conveyed this concept. Initially you
can only see the colour red. This means that you are unable to see
the blue blocks in the world. However, you are still able to collide with
them. They are still "there", even though you are not able to see them. (Take
that post-modernists who insist that models of reality ARE reality.)

## How to play

Use the left and right arrow keys to move left and right and the up arrow key
to jump. Press 'R' and 'B' to toggle the visibility of red and blue blocks
respectively.

## Haxe/OpenFL

This is my first platformer in Haxe/OpenFL. It took me about 7 hours in
total to make this game. I was highly impressed with Haxe's type system
and also its integration with Sublime Text. One of the fantastic things
about the Haxe compiler is that, instead of generating target code, it can
provide information on the program. For instance, it can provide the list of
members and methods a particular value supports. This is not something you can
support with a simple regular expression based syntax highlighting package.
In order to do this the program has to be parsed and type checked, something
that the compiler does anyway. The fact that the Haxe compiler exposes this
functionality so that editors can make use of it is a great idea.

More information is available at: http://haxe.org/manual/completion

## Things I don't like about my implementation

While the collision detecting is accurate, the collision
resolution is absolutely awful. I haven't really thought about collision
resolution should be done. I only have vague intuitions of what goes on
when one collides with an object. This is quite funny because I've been
playing platformers all my life.

For instance, I know that when the player is falling and they "pass through"
the floor I want to "bump" the player up just enough that they're just above
the floor. But I didn't take the direction of motion into account at all,
so you can use this "bump" effect to jump into a wall and then get "bumped"
all the way to the top. Lame.