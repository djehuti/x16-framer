; hworld.p8
; "framer hello world" from the framer project

%zeropage basicsafe
%launcher basic
%option no_sysinit

%import textio

%import framer_main

app {
    sub start() {
        txt.print("hello, world!\n")
    }
}
