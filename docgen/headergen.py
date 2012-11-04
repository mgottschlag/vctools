
import argparse
import regdb
import subprocess
import datetime
import string

file_header = """
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

file_footer = """
#endif
"""

def bitfieldMask(low, high):
    return (0xffffffff << low) & (0xffffffff >> (32 - high - 1))

def generateRegisterDefinitions(reg, group, group_addr):
    offset = reg.offset - group_addr
    text = '#define VC_'
    if reg.array == False:
        text += reg.name + ' (' + group + ' + ' + hex(offset) + ')\n'
        name = reg.name
    else:
        name = reg.name.replace('_${n}', '').replace('_$n', '')
        name = name.replace('${n}_', '').replace('$n_', '').replace('$n', '')
        text += name + '(x) (*(uint32_t*)('
        text += group + ' + ' + hex(offset) + ' + (x) * ' + hex(reg.stride)
        text += '))\n'
    if reg.bits != 0:
        for bitfield in reg.bits:
            bfname = name + '_' + bitfield.name
            text += '#define VC_' + bfname + '__SHIFT ('
            text += str(bitfield.low) + ')\n'
            text += '#define VC_' + bfname + '__MASK ('
            text += hex(bitfieldMask(bitfield.low, bitfield.high)) + ')\n'
            for value in bitfield.values:
                valname = bfname + '_' + value.name
                text += '#define VC_' + valname + ' ('
                text += hex(value.value << bitfield.low)
                text += ')\n'
    return text

def generateGroupDefinitions(group):
    address_name = 'VC_' + group.name + '__ADDRESS'
    text = '#define ' + address_name + ' ' + hex(group.offset) + 'u\n'
    text += '#define VC_' + group.name + '__SIZE ' + hex(group.size) + '\n'
    for reg in group.registers:
        text += generateRegisterDefinitions(reg, address_name, group.offset)
    text += '\n'
    return text

def generateHeader(regdb, filename, vcdbdir):
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
    text = string.Template(file_header).substitute(global_dict)
    # File content
    for group in regdb.groups:
        text += generateGroupDefinitions(group)
    # File footer
    text += file_footer
    # Write the file
    with open(filename, 'w') as f:
        f.write(text)

# Parse the commandline arguments
argparser = argparse.ArgumentParser(
    description='Generate C definitions from the register database.')
argparser.add_argument("vcdb", type=str,
                       help="directory of the register database files")
argparser.add_argument('output', type=str,
                       help='output directory in which generated files are placed')

args = argparser.parse_args()

# Load the file and generate the documentation
db = regdb.RegisterDatabase(args.vcdb + '/_regdb.yaml')

print("Generating the header...")
generateHeader(db, args.output + "/vcregs.h", args.vcdb)
print("Done.")
