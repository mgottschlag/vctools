#!/usr/bin/python
import argparse
import registers.regdb as regdb
import subprocess
import datetime
import string
import registers.decoder as decoder

file_header_c = """
/**
 * VideoCore IV Register Defitions
 *
 * This file was automatically generated from the register database version
 * $VERSION (git) on $DATE.
 * Do not modify!
 */
#ifndef VIDEOCORE_VCREGS_H_INCLUDED
#define VIDEOCORE_VCREGS_H_INCLUDED

"""

file_footer_c = """
#endif
"""

file_header_asm = """
#
# VideoCore IV Register Defitions
#
# This file was automatically generated from the register database version
# $VERSION (git) on $DATE.
# Do not modify!
#

"""

file_footer_asm = """
# end
"""

def bitfieldMask(low, high):
    return (0xffffffff << low) & (0xffffffff >> (32 - high - 1))

def define(is_asm, name, val, u=False):
    if is_asm:
        name += ','
        return ".equ %-40s %s\n" % ('VC_' + name, val)
    else:
        return "#define %-40s (%s%s)\n" % ('VC_' + name, val, u and "u" or "")

def generateRegisterTypeDefinitions(is_asm, regtype, group, group_addr):
    text = ''
    for reg in regtype.registers:
        names = reg.name.split('/')
        for name in names:
            offset = reg.offset - group_addr
            if reg.array == False:
                text += define(is_asm, name, group + ' + ' + hex(offset))
            else:
                if not is_asm:
                    name = name.replace('_${n}', '').replace('_$n', '')
                    name = name.replace('${n}', '').replace('$n', '')
                    val = group + ' + ' + hex(offset)
                    val += ' + (x) * ' + hex(reg.stride)
                    text += define(is_asm, name + '(x)', val)
                else:
                    name = name.replace('_${n}', '_0').replace('_$n', '_0')
                    name = name.replace('${n}', '0').replace('$n', '0')
                    val =  group + ' + ' + hex(offset)
                    text += define(is_asm, name, val)
                    text += define(is_asm, name + '__STRIDE', hex(reg.stride))

    if len(regtype.bits) != 0:
        for bitfield in regtype.bits:
            bfname = regtype.name + '_' + bitfield.name
            text += define(is_asm, bfname + '__SHIFT',
                           str(bitfield.low))
            text += define(is_asm, bfname + '__MASK',
                           "0x%08x" % bitfieldMask(bitfield.low, bitfield.high))
            for value in bitfield.values:
                valname = bfname + '_' + value.name
                text += define(is_asm, valname, "0x%08x" % (value.value << bitfield.low))
            if bitfield.low == bitfield.high and len(bitfield.values) == 0:
                 text += define(is_asm, bfname, 'VC_' + bfname + '__MASK')
    return text

def generateGroupDefinitions(is_asm, group):
    address_name = group.name + '__ADDRESS'
    text = define(is_asm, address_name, hex(group.offset), u=True)
    text += define(is_asm, group.name + '__SIZE', hex(group.size))
    for regtype in group.regtypes.values():
        text += generateRegisterTypeDefinitions(is_asm, regtype, 'VC_' + address_name, group.offset)
    text += '\n'
    return text

def generateCore(regdb, filename, vcdbdir, is_asm, header, footer):
    # Retrieve the git hash of the version
    git = subprocess.Popen(['git', 'rev-parse', 'HEAD'], cwd=vcdbdir,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if git.wait() != 0:
        version = 'UNKNOWN'
    else:
        version = git.stdout.read().rstrip('\n')
    # File header
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    global_dict = dict(DATE=date,
                       VERSION=version)
    text = string.Template(header).substitute(global_dict)
    # File content
    for group in regdb.groups:
        text += generateGroupDefinitions(is_asm, group)
    # File footer
    text += footer
    # Write the file
    with open(filename, 'w') as f:
        f.write(text)

def generateHeader(regdb, filename, vcdbdir):
    generateCore(regdb, filename, vcdbdir, False, file_header_c, file_footer_c)

def generateAsm(regdb, filename, vcdbdir):
    generateCore(regdb, filename, vcdbdir, True, file_header_asm, file_footer_asm)

# Parse the commandline arguments
argparser = argparse.ArgumentParser(
    description='Generate C definitions from the register database.')
argparser.add_argument("vcdb", type=str,
                       help="directory of the register database files")
argparser.add_argument('output', type=str,
                       help='output directory in which generated files are placed')

argparser.add_argument('-d', '--decoder', action="store_true",
                       help='generate code for a register address/value decoder')
argparser.add_argument('-a', '--asm', action="store_true",
                       help='generate assembler header')

args = argparser.parse_args()

# Load the file and generate the documentation
db = regdb.RegisterDatabase(args.vcdb + '/_regdb.yaml')

print("Generating the header...")
generateHeader(db, args.output + "/vcregs.h", args.vcdb)
if args.asm:
    generateAsm(db, args.output + "/vcregs.inc", args.vcdb)
if args.decoder:
    print("Generating the decoder...")
    decoder.generateDecoder(db, args.output, args.vcdb)
print("Done.")
