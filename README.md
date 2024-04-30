# Framer

This is a single-file library (ok, two files, if you use my `main.start`)
in prog8 that implements a small framework for frame-loop-based applications
(read: games) on the X16.

## How To Use It

### tl;dr
```
%import framer

framer.go(myfunction, somevalue)
```
### Tasks

Tasks are functions that the framer will call during its work period, which
(if you use `go`/`resume`) should happen at the start of the vertical blanking
interval (and hopefully finish before the next one).

The task runner supports two types of tasks: "frame tasks", which are
semi-permanent (in that they can be added but not removed), and are executed on
every frame iteration, and "one-shots" which are simple "run this function
on the next frame" requests.

A zero-page (word) location is reserved for passing arguments to these task
functions; it is given as context when adding a task, and can be retrieved
from this zero-page location (`framer.workArg`) when the task is called.
(This way you can, for example, animate multiple mobs on the screen with the
same function, distinguishing them by the context argument.)

#### Frame Tasks

A "frame task" is a function that is called once per frame, on every iteration
through the loop. These are intended to be used for "always-on" services like
music, palette animations, and your main application (game) loop.

These can't be removed, except by calling `framer.reset`. If you want to
pause or stop one of these frame tasks, you can use a state variable to
disable it or something. Or call reset and add back the ones you want.

There are only 32 slots for these by default, because you really should be
combining multiple frame functions if you have that many. You can increase it
to 128 in the source if you want to, at the expense of a word of storage
for each one. (But it has to be a power of 2.) You really should probably
only have a handful of these, though.

When these are called, they simply receive their "task index" (a uword that
starts at 0 for the first registered frame task and increments from there)
in the `workArg`, since they generally shouldn't need us to store context
for them (or they can keep their own).

#### One-Shots

A "one-shot" is a function that will be called one time with the given argument
(placed in the global zero-page `workArg` location before the call).
When added to the queue, the task will not be executed until the _next_
call to `runTasks` (which will occur after the next vertical sync interrupt,
if you're using `go`/`resume`).
(If you want to do something else on _this_ frame, just go ahead and
do it; you don't need framer for that.)

If you want to do something in a future frame, rather than _the next_ one,
consider using a countdown either as the workArg, or in another location
(For example, in a control block pointed to by the workArg). I.e., the work
function checks the countdown value and only does the work if it's 0. If it's
not 0, the work function simply decrements the counter and adds itself again
as a one-shot for the next frame.

### "Modes"

You may choose one of two "modes" of operation:

#### "Managed" Mode

In this mode, you call `framer.go(startFunc, startArg)`, where `startFunc`
is the function you want to call first. `go` won't return until there is no
more work to do, or until the `stop` function is called. "No more work to do"
means that there are no frame tasks defined or one-shots queued.

If `go` returns (because someone called `stop`) then you can `resume` and it
will pick up where it left off (or you can single-frame through by calling
runTask). Note that if it returned because it ran out of stuff to do, it will
return immediately again, so you may need to add some work first.

#### "Manual" Mode

You call `reset` yourself to clear out the list of tasks, and you call the
`runTasks` function yourself on every frame. This way you have complete control
over the frame loop and timing, and `framer` just manages task lists for you.

You can actually mix and match managed and manual mode; just call `stop` to
halt the `go`/`resume` loop and single-step with `runTasks`, then `resume` to
let the framer go back to managing the frame loop.

### Main Loop

If you feel adventurous try `%import`ing `framer_main`, which also defines
a `main.start` that calls `framer.go(app.start, 0)`. So just define an
```
%import textio
%import framer_main
app {
    sub start() {
        txt.print("hello, world!\n")
    }
}
```
and run it. (Then call `framer.addFrameTask` or `addOneShot` from `app.start`
to add work and keep the ball rolling.)

## "Installing" the library

Throw the `lib/framer.p8` and `lib/framer_main.p8` (if you want that one) into
your project, or use the `-srcdirs` command line option to help p8compile find
it in a central location (I recommend `/usr/local/share/prog8`).
Then just `%import framer` (or `%import framer_main`) and go.

## Examples

There are a couple of examples in the `examples` directory. The `Makefile`
should build them, assuming you have `p8compile` on your `PATH` or point
to it in the Makefile.

## Contributing

I welcome pull requests but reserve the right to reject ones that
take this in a direction other than where I want to go (in which case
feel free to fork, this is creative commons).

There's no code of conduct for this project because I doubt anyone
besides me will ever even use this, much less contribute to it.
So the code of conduct is "don't be a jerk."
