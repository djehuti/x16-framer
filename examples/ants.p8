; ants.p8
; framer example that moves "ants" around the screen

%zeropage basicsafe
%launcher basic

%import math
%import syslib
%import textio

%import framer
%import framer_main ; Supplies a main.start that starts up framer and calls app.start

app {
    ; One-shot: start
    ; Called as a one-shot after starting the loop in framer_main's main.start.
    sub start() {
        ; Seed the kernal PRNG
        uword r1 = cbm.RDTIM16()
        sys.waitvsync()
        uword r2 = cbm.RDTIM16()
        math.rndseed(r1, r2)

        ; Screen mode 9 is 64x25. Since we want to fit our ant X coordinates
        ; in 6 bits, and the Y coordinate in 5 bits, that's the best fit.
        void cx16.screen_mode(9, false)

        ; Here are some things we'll do on every frame.
        ; Note that if we don't add any tasks, the app will just quit.
        void framer.addFrameTask(spawner)
        void framer.addFrameTask(showAntCount)
        void framer.addFrameTask(populationControl)
        void framer.addFrameTask(watchForEsc)
    }

    ; Frame task: spawner
    ; The spawner is responsible for spawning an ant when the spawn timer expires
    ; (and resetting the spawn timer to a random interval for the next spawn).
    sub spawner() {
        if spawnTimer != 0 and spawnTimer < $FA {
            spawnTimer--
            return
        }
        if antCount < MAX_ANTS {
            spawnAnt()
        }
        spawnTimer = SPAWN_TIME_MIN + math.randrange(SPAWN_RANGE-SPAWN_TIME_MIN)
    }

    ; Frame task: showAntCount
    ; Update an ant counter in the lower left corner.
    sub showAntCount() {
        txt.plot(0, ROWS-1)
        txt.color(TEXT_COLOR)
        if antCount < 10 {
            txt.print(" ") ; erase any leading digit
        }
        txt.print_ub(antCount)
    }

    ; Frame task: populationControl
    ; Tweak the spawn timer to make it spawn a little faster when there are
    ; fewer ants. Just count it down an extra time if there are very few.
    sub populationControl() {
        ; spawn a little faster the fewer ants there are
        if antCount < GETTING_THIN {
            spawnTimer--
            if antCount < UNDERPOPULATED {
                spawnTimer--
                if antCount < CRITICAL_ANT_SHORTAGE {
                    spawnTimer--
                }
            }
        }
    }

    ; Frame task: watchForEsc()
    ; See if the ESC key is pressed, and quit if it is.
    sub watchForEsc() {
        ubyte @zp ch
        void, ch = cbm.GETIN()
        if ch == ESCAPE {
            ; Escape was pressed. 
            framer.stop()
            ; Remove all of the per-frame tasks and any pending
            ; one-shots.
            framer.reset()
            ; Add a single one-shot to be executed next frame.
            void framer.addOneShot(cbm.CINT, 0)
            ; And resume the loop, which will now run that one-shot and quit.
            framer.resume()
        }
        ; Oh and also... (example of combining two per-frame tasks into one),
        ; show a message in the bottom right of the screen about how to quit.
        if msgTick == MESSAGE_TICK { ; show it when there are 40 ticks left (2/3 sec)
            txt.plot(COLUMNS-18, ROWS-1)
            txt.color(TEXT_COLOR)
            txt.print("press esc to quit")
        }
        if msgTick == UNMESSAGE_TICK { ; erase it until the next time we show it
            txt.plot(COLUMNS-18, ROWS-1)
            txt.print("                 ")
            ; The msgTick counter will now wrap around to $FF
        }
        msgTick--
    }

    ; One-shot: spawnAnt
    ; Called from the spawner frame task when it decides to spawn an ant.
    sub spawnAnt() {
        antCount++
        ticks = ANT_TIME_MIN + math.randrange(TIMER_MAX-ANT_TIME_MIN)
        antx = math.randrange(COLUMNS) as byte
        anty = math.randrange(ROWS-1) as byte ; bottom row reserved for ant count & esc message
        drawAnt()
        reschedule()
    }

    ; One-shot: animAnt
    ; Animates one frame of one ant, whose state is given to us in our 16-bit workArg.
    sub animAnt() {
        ; Grab our state back out of the workArg
        ticks = lsb(framer.workArg >> TIMER_SHIFT) & TIMER_MASK
        antx =  lsb(framer.workArg >> X_SHIFT    ) & X_MASK as byte
        anty =  lsb(framer.workArg >> Y_SHIFT    ) & Y_MASK as byte

        ; If the counter isn't 0 (and isn't large due to rollover), decrement it
        ; and kick the can to the next frame.
        if ticks != 0 and ticks < TIMER_MAX {
            ticks--
            reschedule()
            return
        }

        ; If we get here, it's time for the ant to do _something_.

        ; About 1/ANT_DEATH_ODDS of the time, it will just go away when its turn comes.
        if math.randrange(ANT_DEATH_ODDS) == 0 {
            eraseAnt()
            antCount--
            return ; without rescheduling this ant for another frame
        }

        ; We're gonna move the ant. We don't want to do any floating-point math,
        ; so we're just gonna generate a few random bits and use those to control
        ; our movement.
        ubyte delta = math.rnd()
        ; Low 2 bits are "move now?" -- we only move 1/4 of the time.
        if delta & MOVE_NOW_MASK == 0 {     ; are we going to move?
            ; We are going to move, so remove the current ant.
            eraseAnt()
             ; The next bit controls whether we move horizontally or vertically.
             ; This is its own bit so we won't move diagonally.
            if delta & MOVE_AXIS_MASK == 0 {
                ; We're going to move horizontally. Make the ant horizontal.
                antch = HORIZONTAL_ANT
                ; Are we going to move left or right?
                if delta & MOVE_DIR_MASK == 0 {
                    antx++
                } else {
                    antx--
                }
            } else {
                ; We're going to move vertically. Make the ant vertical.
                antch = VERTICAL_ANT
                ; Up or down?
                if delta & MOVE_DIR_MASK == 0 {
                    anty++
                } else {
                    anty--
                }
            }
            ; Don't walk off the edges of the earth. Here be dragons.
            if antx < 0 {
                antx = 0
            }
            if antx > COLUMNS-1 {
                antx = COLUMNS-1
            }
            if anty < 0 {
                anty = 0
            }
            if anty > ROWS-2 {
                anty = ROWS-2
            }

            ; Now put the ant on the screen in its new position.
            drawAnt()
        }

        ; Reschedule the ant's next move. We are limited to 31 frames out, but we don't
        ; want the number to be too small, or the ant could really fly around.
        ticks = ANT_TIME_MIN + math.randrange(TIMER_MAX-ANT_TIME_MIN)
        reschedule()
    }

    ; Put the ant on the screen.
    sub drawAnt() {
        txt.setcc2(antx as ubyte, anty as ubyte, antch, ANT_COLOR)
    }

    ; Remove the ant from the screen.
    sub eraseAnt() {
        txt.setcc2(antx as ubyte, anty as ubyte, SPACE, BLACK)
    }

    ; Form the timer/anty/antx vars into a context word (workArg) and reschedule an
    ; animAnt call with this ant's state for next frame (which will decrement the
    ; timer and keep getting rescheduled each frame until its time comes).
    sub reschedule() {
        void framer.addOneShot(animAnt,
            (((ticks & TIMER_MASK) as uword) << TIMER_SHIFT) |
            (((anty  & Y_MASK    ) as uword) << Y_SHIFT    ) |
            (((antx  & X_MASK    ) as uword) << X_SHIFT    ))
    }

    ; Configuration parameters
    const byte  COLUMNS        = 64
    const byte  ROWS           = 25
    const ubyte MAX_ANTS       = 50
    const ubyte SPAWN_RANGE    = 240 ; maximum # of frames between spawns
    const ubyte SPAWN_TIME_MIN = 30  ; minimum # of frames between spawns
    const ubyte ANT_TIME_MIN   = 10  ; minimum # of frames between ant moves
    const ubyte HORIZONTAL_ANT = $68 ; character representing a horizontal ant
    const ubyte VERTICAL_ANT   = $5C ; vertical ant
    const ubyte ANT_COLOR      = 9   ; brown
    const ubyte TEXT_COLOR     = 12  ; dark gray
    const ubyte BLACK          = 0

    const ubyte ESCAPE = 27
    const ubyte SPACE  = 32

    ; Movement control bit masks
    const ubyte MOVE_NOW_MASK    = %00000011 ; Test against 0 for 1/4 chance to move
    const ubyte MOVE_AXIS_MASK   = %00000100 ; 0 for horizontal, 1 for vertical
    const ubyte MOVE_DIR_MASK    = %00001000 ; 0 for right/down, 1 for left/up

    ; Packing the ant state into the 16-bit workArg:
    const ubyte X_SHIFT     = 0    ; these are the LSBs
    const ubyte X_MASK      = $3F  ; Lowest 6 bits (0-63)
    const ubyte Y_SHIFT     = 6    ; Shift 6 bits and mask with $1F to get Y
    const ubyte Y_MASK      = $1F  ; Y is 5 bits (0-23)
    const ubyte TIMER_SHIFT = 11   ; Shift 11 bits and mask with $1F to get timer
    const ubyte TIMER_MASK  = $1F  ; Timer is 5 bits (0-31)
    const ubyte TIMER_MAX   = $1C  ; highest few values are underflow

    ; When we show and hide the escape message
    const ubyte MESSAGE_TICK   = 40
    const ubyte UNMESSAGE_TICK = 0

    ; Population thresholds for speeding up ant spawning
    const ubyte CRITICAL_ANT_SHORTAGE = 5
    const ubyte UNDERPOPULATED = 8
    const ubyte GETTING_THIN = 13
    const ubyte ANT_DEATH_ODDS = 200

    ; Keeping track of the count to keep from overflowing, and to
    ; use it to affect the spawn rate (and so we can show it).
    ubyte antCount = 0

    ; The countdown timer for blinking the escape message
    ubyte @zp msgTick = MESSAGE_TICK + 1

    ; The countdown timer for spawning new ants
    ubyte @zp spawnTimer = 0

    ; Temporary scratch state used within animAnt/drawAnt/reschedule.
    ubyte antch = HORIZONTAL_ANT
    ubyte @zp ticks
    byte @zp antx
    byte @zp anty
}
