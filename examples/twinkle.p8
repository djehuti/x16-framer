; twinkle.p8
; Draws a starfield and palette-animates a few of the stars

%zeropage basicsafe
%launcher basic

%import floats
%import syslib
%import textio

%import framer
%import framer_main

app {
    const ubyte ESCAPE = 27
    const ubyte SPACE = 32

    sub start() {
        ; Set up the screen.
        initscreen()

        ; Start the keyboard watcher.
        control.start()

        ; Start the twinkler
        void = framer.addFrameTask(animatePalette)
    }

    sub initscreen() {
        cx16.VERA_CTRL = 0 ; set DCSEL and ADDRSEL to 0
        ; Turn on layer 0
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11001111) | %00010000
        cx16.VERA_DC_HSCALE = 64 ; make picture 320px wide
        cx16.VERA_DC_VSCALE = 48 ; and 240px tall
        cx16.VERA_L0_CONFIG =    %00000111 ; 320x240x256c
        cx16.VERA_L0_TILEBASE =  %00000000 ; with bitmap at $0:0000

        ; Write all black
        cx16.VERA_ADDR_L = 0
        cx16.VERA_ADDR_M = 0
        cx16.VERA_ADDR_H = $10
        repeat 240 {
            repeat 320 {
                cx16.VERA_DATA0 = 0
            }
        }

        ; Generate 80 stars between colors 16-31 (these won't twinkle)
        repeat 80 {
            color = ((floats.rnd() * 16.0) as ubyte) + 16
            randomStar_()
        }
        ; Generate 8 more between colors 1-15 (these will twinkle)
        repeat 8 {
            color = ((floats.rnd() * 15.0) as ubyte) + 1
            randomStar_()
        }
    }

    sub restorescreen() {
        cbm.CINT()
    }

    sub randomStar_() {
        uword @zp xcoord = (floats.rnd() * 320.0) as uword
        ubyte @zp ycoord = (floats.rnd() * 240.0) as ubyte
        uword @zp vaddr = xcoord + ycoord * 320 ; this needs 17 bits
        cx16.VERA_ADDR_L = lsb(vaddr)
        cx16.VERA_ADDR_M = msb(vaddr)
        if ycoord > 200 and vaddr < 32768 {
            cx16.VERA_ADDR_H = $01
        } else {
            cx16.VERA_ADDR_H = $00
        }
        cx16.VERA_DATA0 = color
    }

    ; Called by the control frame task when a key has been pressed.
    sub handleKey() {
        if control.ch == ESCAPE {
            framer.stop()
            restorescreen()
        }
        if control.ch == SPACE {
            paused = not paused
        }
    }

    sub animatePalette() {
        if paused {
            return
        }
        if timer != 0 {
            ; If timer is >=250, assume it underflowed.
            if timer < 250 {
                timer--
                return
            }
        }

        paletteOffset = (paletteOffset + 1) & $0F
        timer = 40

        cx16.VERA_L0_HSCROLL_H = paletteOffset
    }

    ubyte @zp color
    ubyte @zp timer
    ubyte @zp paletteOffset = 0
    bool @zp paused = false
}

; This frame task watches for keystrokes and calls app.handleKey() for them.
control {
    sub start() {
        void = framer.addFrameTask(poll_)
    }

    sub poll_() {
        void, ch = cbm.GETIN()
        if ch != 0 {
            goto app.handleKey ; avoid a stack frame
        }
    }

    ubyte @zp ch
}
