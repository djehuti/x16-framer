; ants.p8
; framer example that moves "ants" around the screen

%zeropage basicsafe
%launcher basic

%import math
%import syslib
%import textio

%import framer
%import framer_main

app {
    sub start() {
        uword r1 = cbm.RDTIM16()
        sys.waitvsync()
        uword r2 = cbm.RDTIM16()
        math.rndseed(r1, r2)
        void cx16.screen_mode(9, false)
        void framer.addFrameTask(spawner)
        void framer.addFrameTask(showAntCount)
        void framer.addFrameTask(populationControl)
        void framer.addFrameTask(watchForEsc)
    }

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

    sub showAntCount() {
        txt.plot(0, 24)
        txt.color(12)
        if antCount < 10 {
            txt.print(" ")
        }
        txt.print_ub(antCount)
    }

    sub populationControl() {
        ; spawn a little faster the fewer ants there are
        if antCount < 5 {
            spawnTimer--
        }
        if antCount < 8 {
            ; yes this will decrement it again for <5
            spawnTimer--
        }
        if antCount < 13 {
            spawnTimer--
        }
    }

    sub watchForEsc() {
        ubyte @zp ch
        void, ch = cbm.GETIN()
        if ch == 27 {
            framer.stop()
            framer.reset()
            void framer.addOneShot(cbm.CINT, 0)
            framer.resume()
        }
        if msgTick == 40 {
            txt.plot(43, 24)
            txt.color(12)
            txt.print("press esc to quit")
        }
        if msgTick == 0 {
            txt.plot(43, 24)
            txt.print("                 ")
        }
        msgTick--
    }

    sub spawnAnt() {
        antCount++
        ticks = ANT_TIME_MIN + math.randrange(31-ANT_TIME_MIN)
        antx = math.randrange(COLUMNS) as byte
        anty = math.randrange(ROWS) as byte
        drawAnt()
        reschedule()
    }

    sub animAnt() {
        ticks = lsb(framer.workArg >> 11) & $1F
        antx = lsb(framer.workArg) & $3F as byte
        anty = lsb(framer.workArg >> 6) & $1F as byte

        if ticks != 0 and ticks < $1A {
            ticks--
            reschedule()
            return
        }

        ; Ant disappears after some # of turns (1/64 chance per move)
        if math.rnd() & $3F == 0 {
            eraseAnt()
            antCount--
            return
        }

        ubyte delta = math.rnd()
        if delta & %00000011 == 0 {     ; are we going to move?
            eraseAnt()
            if delta & %00000100 == 0 { ; x or y?
                antch = $68
                if delta & %00001000 == 0 { ; left or right?
                    antx++
                } else {
                    antx--
                }
            } else {
                antch = $5C
                if delta & %00001000 == 0 {
                    anty++
                } else {
                    anty--
                }
            }
            if antx < 0 {
                antx = 0
            }
            if antx > COLUMNS-1 {
                antx = COLUMNS-1
            }
            if anty < 0 {
                anty = 0
            }
            if anty > ROWS-1 {
                anty = ROWS-1
            }
            drawAnt()
        }

        ticks = ANT_TIME_MIN + math.randrange(31-ANT_TIME_MIN)
        reschedule()
    }

    sub drawAnt() {
        txt.setcc2(antx as ubyte, anty as ubyte, antch, 9)
    }

    sub eraseAnt() {
        txt.setcc2(antx as ubyte, anty as ubyte, $20, 0)
    }

    sub reschedule() {
        void framer.addOneShot(animAnt,
            (((ticks & $1F) as uword) << 11) |
            (((anty  & $1F) as uword) <<  6) |
            (((antx  & $3F) as uword)      ))
    }

    const ubyte MAX_ANTS = 30
    const byte COLUMNS = 64
    const byte ROWS = 25
    const ubyte SPAWN_RANGE = 240
    const ubyte SPAWN_TIME_MIN = 10
    const ubyte ANT_TIME_MIN = 24
    ubyte antCount
    ubyte antch = $68 ; bottom half hash
    ubyte @zp msgTick = 41
    ubyte @zp spawnTimer = 0
    ubyte @zp ticks
    byte @zp antx
    byte @zp anty
}
