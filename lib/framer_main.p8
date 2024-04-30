; framer_main.p8 - Miniature frame-based app/task framework startup function.
; by Ben Cox <cox@djehuti.com>
; Released under Creative Commons; see LICENSE for details.

%import framer

main {
    sub start() {
        framer.go(app.start, 0)
    }
}
