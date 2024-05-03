; ants.p8
; framer example that moves "ants" around the screen

%zeropage basicsafe
%launcher basic

%import floats
%import syslib
%import textio

%import framer
%import framer_main

app {
    sub start() {
        void framer.addFrameTask(spawner)
        void framer.addFrameTask(populationControl)
    }

    sub spawner() {
        if spawnTimer != 0 and spawnTimer < $FA {
            spawnTimer--
            return
        }
        spawnAnt()
        spawnTimer = (floats.rnd() * 120) as ubyte
    }

    sub populationControl() {
        if antCount < 5 {
            spawnTimer--
        }
        if antCount < 10 {
            ; yes this will decrement it again for <5
            spawnTimer--
        }
        if antCount < 15 {
            spawnTimer--
        }
        if antCount > 50 {
            spawnTimer = 20
        }
    }

    sub spawnAnt() {
        antCount++
        ticks = (floats.rnd() * 32) as ubyte
        antx = (floats.rnd() * 64) as byte
        anty = (floats.rnd() * 32) as byte
        drawAnt()
        reschedule()
    }

    sub animAnt() {
        ticks = lsb((framer.workArg >> 11) & $1F)
        if ticks != 0 {
            if ticks < $18 {
                ticks--
                reschedule()
                return
            }
        }
        antx = lsb(framer.workArg & $3F) as byte
        anty = lsb((framer.workArg >> 6) & $1F) as byte
        eraseAnt()

        float r = floats.rnd()
        if r < 0.03 {
            ; Ant disappears after some # of turns
            antCount--
            return
        }

        byte delta = ((r * r * 3) - 1) as byte
        if delta < 0 and antx <= 0 {
            delta = 0
            antx = 0
        }
        if delta > 0 and antx >= 63 {
            delta = 0
            antx = 63
        }
        antx = antx + delta

        r = floats.rnd()
        delta = ((r * r * 3) - 1) as byte
        if delta < 0 and anty <= 0 {
            delta = 0
            anty = 0
        }
        if delta > 0 and anty >= 31 {
            delta = 0
            anty = 31
        }
        anty = anty + delta

        drawAnt()

        r = floats.rnd()
        ticks = (31 - (r * r * 32)) as ubyte
        reschedule()
    }

    sub drawAnt() {
        txt.plot(antx as ubyte, anty as ubyte)
        txt.print("@")
    }

    sub eraseAnt() {
        txt.plot(antx as ubyte, anty as ubyte)
        txt.print(" ")
    }

    sub reschedule() {
        void framer.addOneShot(animAnt, (ticks as uword << 11) | (anty as uword << 6 ) | antx as uword)
    }

    ubyte antCount
    ubyte @zp spawnTimer = 0
    ubyte @zp ticks
    byte @zp antx
    byte @zp anty
}
