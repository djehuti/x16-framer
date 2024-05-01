; ants.p8
; framer example that moves "ants" around the screen

%zeropage basicsafe
%launcher basic

%import syslib
%import textio

%import framer
%import framer_main

app {
    sub start() {
        txt.print("ants\n")
    }
}
