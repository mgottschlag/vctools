#!/bin/sh
python ../docgen/headergen.py --decoder ../vcdb .
gcc vcdecoder.c -c -o vcdecoder.o -Wall -Wextra
g++ trace_decoder.cpp vcdecoder.o -o trace_decoder -Wall -Wextra
