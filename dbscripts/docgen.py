#!/usr/bin/python
import argparse
import regdb
import latex
import markdown

# Parse the commandline arguments
argparser = argparse.ArgumentParser(
    description='Generate documentation from the register database.')
argparser.add_argument("vcdb", type=str,
                       help="directory of the register database files")
argparser.add_argument('output', type=str,
                       help='output directory in which generated files are placed')
argparser.add_argument('-l', '--latex', action="store_true",
                       help='generate LaTeX files')
argparser.add_argument('-m', '--md', action="store_true",
                       help='generate markdown files')

args = argparser.parse_args()

if not args.md and not args.latex:
    print("One of --md or --latex needs to be specified!")
    quit()

# Load the file and generate the documentation
db = regdb.RegisterDatabase(args.vcdb + '/_regdb.yaml')

if args.md:
    print("Generating markdown...")
    markdown.generateMarkdown(db, args.output + "/vcregs.md", args.vcdb)
if args.latex:
    print("Generating LaTeX source...")
    latex.generateLatex(db, args.output + "/vcregs.tex", args.vcdb)
print("Done.")
