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
    const ubyte SPACE = ' '
    const ubyte DOT = '.'

    sub start() {
        ; Set up the screen.
        initscreen()

        ; Start the keyboard watcher.
        control.start()

        ; Start the twinkler
        void framer.addFrameTask(animatePalette)

        ; Start the scroller
        void framer.addFrameTask(vScroller)
        void framer.addFrameTask(hScroller)
    }

    sub initscreen() {
        cx16.VERA_CTRL = 0 ; set DCSEL and ADDRSEL to 0
        ; Turn on layer 0
        cx16.VERA_DC_VIDEO = (cx16.VERA_DC_VIDEO & %11101111) | %00010000
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

        txt.color(5)
        txt.plot(12, 9)
        txt.print("twinkle twinkle")
        txt.plot(12, 11)
        txt.print("space to  pause")
        txt.plot(14, 13)
        txt.print("esc to quit")
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
        when control.ch {
            ESCAPE -> {
                framer.stop()
                restorescreen()
            }
            SPACE -> {
                hPaused = not hPaused
                paused = not paused
                if paused {
                    txt.plot(12, 9)
                    txt.print("still twinkling")
                    txt.plot(21, 11)
                    txt.print("resume")
                } else {
                    txt.plot(12, 9)
                    txt.print("twinkle twinkle")
                    txt.plot(21, 11)
                    txt.print(" pause")
                }
            }
            DOT -> {
                ; sooper seekrit undocumented feature
                hPaused = not hPaused
            }
        }
    }

    sub animatePalette() {
        ; If timer is >=250, assume it underflowed.
        if timer != 0 and timer < 250 {
            timer--
            return
        }

        paletteOffset = (paletteOffset + 1) & $0F
        timer = 40

        cx16.VERA_L0_HSCROLL_H = paletteOffset
    }

    sub vScroller() {
        if scrollTimer != 0 and scrollTimer < 250 {
            scrollTimer--
            return
        }
        if paused {
            return
        }
        if scrollingUp {
            scrollPos++
            if scrollPos > SCROLL_MAX {
                scrollPos = SCROLL_MAX
                scrollingUp = false
            }
        } else {
            if scrollPos == 0 {
                scrollingUp = true
            } else {
                scrollPos--
            }
        }
        scrollTimer = 8 + 3*abs(SCROLL_START as byte - scrollPos as byte) as ubyte
        cx16.VERA_L1_VSCROLL_L = scrollPos
    }

    sub hScroller() {
        if hPaused {
            return
        }
        if hScrollTimer != 0 {
            if hScrollTimer < 250 {
                hScrollTimer--
                return
            }
        } 
        if scrollingLeft {
            hScrollPos++
            if hScrollPos > HSCROLL_MAX {
                hScrollPos = HSCROLL_MAX
                scrollingLeft = false
            }
        } else {
            if hScrollPos == 0 {
                scrollingLeft = true
            } else {
                hScrollPos--
            }
        }
        hScrollTimer = 3 + 2*abs(HSCROLL_START as byte - hScrollPos as byte) as ubyte
        cx16.VERA_L1_HSCROLL_L = hScrollPos
    }

    ubyte @zp timer
    ubyte @zp paletteOffset = 0

    ; Variables for the vertical scroller
    const ubyte SCROLL_MAX = 30
    const ubyte SCROLL_START = SCROLL_MAX/2
    ubyte @zp scrollTimer
    ubyte @zp scrollPos = SCROLL_START
    bool @zp scrollingUp = true ; increasing scroll (picture moving up)
    bool @zp paused = false

    ; Vars for the horizontal scroller
    const ubyte HSCROLL_MAX = 13
    const ubyte HSCROLL_START = HSCROLL_MAX/2
    ubyte @zp hScrollTimer
    ubyte @zp hScrollPos = HSCROLL_START
    bool @zp scrollingLeft = false ; increasing hscroll (picture moving left)
    bool @zp hPaused = false

    ubyte @zp color
}


; This frame task watches for keystrokes and calls app.handleKey() for them.
control {
    sub start() {
        void framer.addFrameTask(poll_)
    }

    sub poll_() {
        void, ch = cbm.GETIN()
        if ch != 0 {
            goto app.handleKey ; avoid a stack frame
        }
    }

    ubyte @zp ch
}
