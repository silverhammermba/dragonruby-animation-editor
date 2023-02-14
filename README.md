# What is this?

Two things:

1. A collection of tools for doing cool animation stuff in DragonRuby
2. A DragonRuby-based GUI for quick prototyping with said tools

## How do I use it?

If you only need the tools, clone this and copy whatever files you need from
`lib` into your game.

If you also want the GUI, get a fresh copy of DragonRuby and copy the entire
contents of this repo into the `mygame` directory, overwriting `app/main.rb`.
Then run the game. I will also make the GUI available for download on Itch.io in
the near future.

## The tools

### Bezier.ease

Create a cubic bezier easing function, suitable for using with DragonRuby's
built-in `Easing.ease` method.

Note that DragonRuby has a built-in cubic bezier function, but it is only useful
for computing a traditional 2-dimensional bezier curve (input t to get (x, y)).
`Bezier.ease` produces a 1-dimensional bezier curve (input x to get y) which
is what you want for an easing function. See [here][bez] for more explanation of
the difference between these kinds of curves.

[bez]: https://asawicki.info/articles/Bezier_Curve_as_Easing_Function.htm

This works the same as your web browser's `cubic-bezier` CSS function, so any
resources about that function (such as [cubic-bezier.com][cb]) apply to this as
well!

[cb]: https://cubic-bezier.com

### Enum Utils

Functions for managing keyframe animations using Ruby's `Enumerator`. In a
nutshell, these let you create animation objects that automatically manage
animation state independently of the `tick` method.

* `ecount` for encapsulating a tick-based animation where you only need the
  number of ticks since the animation started
* `eease` for encapsulating an easing-based animation where you get the progress
  of the animation as a number from 0 to 1. Takes an easing functions (such as
  those produced by `Bezier.ease`) to tweak the "feel" of the animation
* `Enumerator::Yielder.run` for composing individual animations into larger ones
* `create_easing_func` for creating easing functions in a way similar to
  DragonRuby's built-in `ease`, but with unconstrained output so that your
  functions can anticipate/overshoot during the animation
* `Numeric#lerp` for doing a linear interpolation between two numbers. Handy to
  call on the output of an easing function

See my [blog post][enum] for more details.

[enum]: https://silverhammermba.github.io/blog/2023/02/08/animation

### Second Order Dynamics

`SecOrdDyn` is a class that encapsulates a second-order dynamic system. In
English, it lets you add physical properties (springiness, momentum, etc.) to
any 2-dimensional input (such as position).

For example, say a sprite's position is unpredictable (dependent on user input
or randomness). Then you can't use easing functions to tweak its movement
because you don't know where it will be in the future. But you _can_ create a
`SecOrdDyn` and feed it a _desired_ position each frame, then the system will
output an actual position to use for the sprite, and you can tweak the "feel" of
the movement simply by modifying the parameters of the system.

See this [video][dyn] for more info.

[dyn]: https://www.youtube.com/watch?v=KPoeNZZ6H4s

### VectorLike

This module can be included to add 2D vector math operations to any class that
responds to the `x` and `y` methods. By default I include it in `Array`
(DragonRuby treats two-element arrays as vectors) and `Mouse` but it can
probably be included in a bunch of other stuff too.

### Clipboard

Allows you to copy/paste strings from the system clipboard. Works on Mac,
Windows, and Linux (if you have the right packages installed).

Totally unrelated to animation but I needed it for the GUI, so here it is.

## The GUI

Running `main.rb` in DragonRuby lets you play around with `Bezier.ease` and
`SecOrdDyn`. Since these two components are all about achieving the right
"feel", they are very hard to use if you're only looking at the numbers.

The two UIs (selected with B/D) let you tweak the parameters, see a preview, and
finally Ctrl-C to copy the code for reproducing that feel in your game!
