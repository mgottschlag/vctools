
all: bin/bootloader.bin bin/tracer.bin

clean:
	-rm -rf bin obj vcregs.inc vcregs.h

vcregs.inc: ../vcdb/*.yaml
	python ../dbscripts/headergen.py --asm ../vcdb .

obj/%.o: %.s vcregs.inc
	@mkdir -p obj
	vc4-as $^ -o $@

# bootloader

obj/draminit_include.o: obj/draminit.bin
	vc4-objcopy -F elf32-vc4 -B vc4 -I binary $^ $@

bin/bootloader.bin: obj/bootloader.o obj/draminit_include.o
	@mkdir -p bin
	vc4-ld -T bootloader.ld -o $@ $^

# draminit

obj/draminit.bin: obj/draminit.o
	@mkdir -p bin
	vc4-ld -T program.ld -o $@ $^

# tracer

bin/tracer.bin: obj/tracer.o
	@mkdir -p bin
	vc4-ld -T program.ld -o $@ $^

