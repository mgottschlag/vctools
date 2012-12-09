
CFLAGS = -g -Wall -Wextra
CFLAGS_VC4_EMUL = -g

all: bcm2835_emul

bcm2835_emul: main.o vc4_emul.o memory.o devices/mmc.o devices/aux.o \
              devices/otp.o devices/gpio.o devices/timer.o devices/cm.o
	gcc -o $@ $^ $(CFLAGS) -lm

vc4_emul.o: vc4_emul.c
	gcc -c -o $@ $^ $(CFLAGS_VC4_EMUL)

%.o: %.c vc4_emul.h vcregs.h bcm2835_emul.h devices/cm.h
	gcc -c -o $@ $< $(CFLAGS)

vc4_emul.h: vc4_emul.c

vc4_emul.c: ../vcdb/_instructions.yaml
	python ../dbscripts/emulgen.py ../vcdb .

vcregs.h:
	python ../dbscripts/headergen.py ../vcdb .

clean:
	-rm -f bcm2835_emul
	-rm -f *.o devices/*.o
	-rm -f vc4_emul.h vc4_emul.c vcregs.h

