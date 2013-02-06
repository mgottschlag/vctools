#!/bin/sh
python ../dbscripts/headergen.py --decoder ../vcdb .
gcc vcdecoder.c -c -o vcdecoder.o -Wall -Wextra
g++ trace_decoder.cpp vcdecoder.o -o trace_decoder -Wall -Wextra
g++ dump_decoder.cpp vcdecoder.o -o dump_decoder -Wall -Wextra
