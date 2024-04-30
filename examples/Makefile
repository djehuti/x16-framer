# Makefile

PROGS=hworld.prg twinkle.prg

P8COMPILE=p8compile
P8FLAGS=-target cx16 -quietasm -warnshadow -srcdirs ../lib

all: $(PROGS)

clean:
	$(RM) $(PROGS)  *.asm *.vice-mon-list



# -----------------------------
.p8.prg:
	$(P8COMPILE) $(P8FLAGS) $<

.PHONY: all clean
.SUFFIXES: .prg .p8
