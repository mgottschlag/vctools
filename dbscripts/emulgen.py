#!/usr/bin/python
import argparse
import instructions.instrdb as instrdb
import instructions.emulator as emulator

# Parse the commandline arguments
argparser = argparse.ArgumentParser(
    description='Generate an emulator from instruction descriptions.')
argparser.add_argument("vcdb", type=str,
                       help="directory of the videocore database files")
argparser.add_argument('output', type=str,
                       help='output directory in which generated files are placed')

args = argparser.parse_args()

# Load the file and generate the documentation
db = instrdb.InstructionDatabase(args.vcdb + '/_instructions.yaml')
print("Generating the emulator...")
emulator.generateEmulator(db, args.output + '/vc4_emul.c',
                          args.output + '/vc4_emul.h', args.vcdb)
print("Done.")
