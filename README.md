
VideoCore Tools
===============

This repository contains a number of tools usable for reverse engineering the
VideoCore CPU or for writing software for it.

Register Database
-----------------

In the directory `vcdb` there is a database containing documentation about most
known hardware registers in the area starting at 0x7e000000. The database is in
yaml format, with one file for every register region. The central file which
includes all other files is `vcdb/_regdb.yaml`.

Documentation Generator
-----------------------

The directory `docgen` contains a program which creates a PDF or markdown file
from the register database (`docgen/docgen.py`). Use it to create PDF
documentation like this (which will place the output files in `.`):

    python docgen/docgen.py --latex vcdb .
    pdflatex vcregs.tex

In order to run `pdflatex` to generate the PDF, you need the `bytefield` package
from http://www.ctan.org/pkg/bytefield!

If you want to generate markdown, call the program like this:

    python docgen/docgen.py --md vcdb .

Header Generator
----------------

The directory `docgen` also contains a program which creates a C header file
containing all documented registers and register groups. To generate the file,
call it like this:

    python docgen/docgen.py vcdb .

The last parameter again specifies the directory in which the header file
(called `vcregs.h`) is placed.

Register Trace Decoder
----------------------


The directory `trace_decoder` contains a program which processes register traces
produced by resim and replaces addresses/values by their names if they are
documented in the register database.

To compile the program, simply execute `compile.sh` from within the
`trace_decoder` directory. To convert a trace, pipe it into the program, then
the converted data is printed on stdout:

    ./trace_decoder < vc4emul.log > decoded.log
