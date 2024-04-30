# Makefile

# -----------------------------
# Definitions

PROGS=hworld.prg twinkle.prg

P8COMPILE=p8compile
P8FLAGS=-target cx16 -quietasm -warnshadow -srcdirs ../lib

# -----------------------------
# Targets

all: $(PROGS)

clean:
	$(RM) $(PROGS)  *.asm *.vice-mon-list


# -----------------------------
# Dependencies

hworld.prg: hworld.p8 ../lib/framer.p8 ../lib/framer_main.p8
twinkle.prg: twinkle.p8 ../lib/framer.p8 ../lib/framer_main.p8

# -----------------------------
# Administrivia

.p8.prg:
	$(P8COMPILE) $(P8FLAGS) $<

.PHONY: all clean
.SUFFIXES: .prg .p8
