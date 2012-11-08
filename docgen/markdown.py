
import datetime
import string
import subprocess

markdown_template = """
# Register Documentation #

This document was automatically generated on $DATE from the videocore
register database, git commit $VERSION. *Do not modify!*

## List of MMIO Regions ##

<table>
<tr><th>Address</th><th>Size</th><th>Name</th><th>Description</th></tr>
$REGION_TABLE_ENTRIES
</table>

$REGIONS"""

markdown_region_table_template = """
<tr><td>$REGION_ADDRESS</td><td>$REGION_SIZE</td><td><a href="#wiki-$REGION_ANCHOR">$REGION_NAME</a></td><td>$REGION_BRIEF</td></tr>"""

markdown_region_template = """
## <a name="$REGION_ANCHOR"></a>$REGION_NAME: $REGION_BRIEF ##

### Description ###

$REGION_DESC

### Registers ###

<table>
<tr><th>Address</th><th>Access</th><th>Name</th><th>Description</th></tr>
$REGISTER_TABLE_ENTRIES
</table>

$REGISTERS
"""

markdown_register_table_template = """
<tr><td>$REGISTER_ADDRESS</td><td>$REGISTER_ACCESS</td><td>$REGISTER_NAME</td><td>$REGISTER_BRIEF</td></tr>"""

markdown_register_template = """
### $REGISTER_TYPE_CAPTION ###

<table>
$REGISTER_TYPE_LIST
</table>

#### Description ####

$REGISTER_TYPE_DESC

#### Details ####

$BITFIELD_TABLE
"""

bitfield_table_header = """
<table>
<tr><th>Bits</th><th>Name</th><th>Description</th><th>Access</th></tr>"""

bitfield_table_footer = """
</table>"""

def formatAccess(access):
    if access == 'r':
        return 'R'
    if access == 'w':
        return 'W'
    if access == 'rw':
        return 'R/W'
    if access == '?w':
        return '?/W'
    if access == 'r/?':
        return 'R/?'
    return access

def generateValueTable(values):
    text = '<table>\n<tr><th>'
    text += 'Value</th><th>Name</th><th>Description</th></tr>\n'
    for value in values:
        text += '<tr><td>'
        text += hex(value.value) + '</td><td>'
        text += value.name + '</td><td>'
        text += value.desc + '</td></tr>\n'
    text += '</table>\n'
    return text

def generateBitfieldTable(bits):
    if len(bits) == 0:
        return ''
    text = bitfield_table_header
    for bitfield in bits:
        text += '<tr><td>'
        low = bitfield.low
        high = bitfield.high
        if low == high:
            text += str(low)
        else:
            text += str(high) + '-' + str(low)
        text += '</td><td>' + bitfield.name
        text += '</td><td>' + bitfield.desc
        if len(bitfield.values) != 0:
            text += '\n' + generateValueTable(bitfield.values)
        text += '</td><td>' + formatAccess(bitfield.access) + '</td></tr>'
    text += bitfield_table_footer
    return text

def generateRegisterAddress(reg):
    if not reg.array:
        return hex(reg.offset)
    else:
        return hex(reg.offset) + '+i*' + hex(reg.stride)

def generateRegisterName(reg):
    if not reg.array:
        return reg.name
    else:
        template = string.Template(reg.name)
        return template.substitute(n='[0-' + str(reg.count - 1) + ']')

#def generateRegisterTable(group):
    #text = ''
    #template = string.Template(markdown_register_table_template)
    #for reg in group.registers:
        #regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       #REGISTER_ACCESS=formatAccess(reg.access),
                       #REGISTER_NAME=generateRegisterName(reg),
                       #REGISTER_BRIEF=reg.brief,
                       #REGISTER_DESC=reg.desc)
        #text += template.substitute(regdict)
    #return text;

#def generateRegisterDocumentation(group):
    #text = ''
    #template = string.Template(markdown_register_template)
    #for reg in group.registers:
        #regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       #REGISTER_ACCESS=formatAccess(reg.access),
                       #REGISTER_NAME=generateRegisterName(reg),
                       #REGISTER_BRIEF=reg.brief,
                       #REGISTER_DESC=reg.desc,
                       #BITFIELD_TABLE=generateBitfieldTable(reg))
        #text += template.substitute(regdict)
    #return text;

def generateRegisterTable(group):
    text = ''
    template = string.Template(markdown_register_table_template)
    for reg in group.registers:
        regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       REGISTER_ACCESS=formatAccess(reg.regtype.access),
                       REGISTER_NAME=generateRegisterName(reg),
                       REGISTER_BRIEF=reg.brief,
                       REGISTER_DESC=reg.regtype.desc)
        text += template.substitute(regdict)
    return text;

def generateRegisterTypeDocumentation(regtype):
    if regtype.brief != '':
        caption = regtype.brief
    else:
        caption = ''
    if len(regtype.registers) <= 4 or regtype.brief == '':
        if regtype.brief != '':
            caption += ' ('
        caption += ', '.join(map(generateRegisterName, regtype.registers))
        if regtype.brief != '':
            caption += ')'

    reglist = ''
    for register in regtype.registers:
        reglist += '<tr><td>'
        reglist += generateRegisterAddress(register) + '</td><td>'
        reglist += generateRegisterName(register) + '</td><td>'
        reglist += register.brief + '</td></tr>\n'

    template = string.Template(markdown_register_template)
    regdict = dict(REGISTER_TYPE_CAPTION=caption,
                   REGISTER_TYPE_LIST = reglist,
                   REGISTER_TYPE_DESC=regtype.desc,
                   BITFIELD_TABLE=generateBitfieldTable(regtype.bits))
    return template.substitute(regdict)

def generateRegisterDocumentation(group):
    text = ''
    # Sort the register types by the address of the first register
    regtypes = sorted(group.regtypes.values(),
                      key=lambda k : k.registers[0].offset)
    for regtype in regtypes:
        text += generateRegisterTypeDocumentation(regtype)
    return text;

def generateRegionTable(db):
    text = ''
    template = string.Template(markdown_region_table_template)
    for i, group in enumerate(db.groups):
        groupdict = dict(REGION_ADDRESS=hex(group.offset),
                         REGION_SIZE=hex(group.size),
                         REGION_NAME=group.name,
                         REGION_BRIEF=group.brief,
                         REGION_DESC=group.desc,
                         REGION_ANCHOR='region_' + str(i))
        text += template.substitute(groupdict)
    return text;

def generateRegionDocumentation(db):
    text = ''
    template = string.Template(markdown_region_template)
    for i, group in enumerate(db.groups):
        if len(group.registers) == 0 and (group.desc.strip() == ''
                                    or group.desc.strip() == 'TBD'):
            # Skip empty groups
            continue
        groupdict = dict(REGION_ADDRESS=hex(group.offset),
                         REGION_SIZE=hex(group.size),
                         REGION_NAME=group.name,
                         REGION_BRIEF=group.brief,
                         REGION_DESC=group.desc,
                         REGISTER_TABLE_ENTRIES=generateRegisterTable(group),
                         REGISTERS=generateRegisterDocumentation(group),
                         REGION_ANCHOR='region_' + str(i))
        text += template.substitute(groupdict)
    return text;

def generateMarkdown(db, filename, vcdbdir):
    # Retrieve the git hash of the version
    git = subprocess.Popen(['git', 'rev-parse', 'HEAD'], cwd=vcdbdir,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if git.wait() != 0:
        version = 'UNKNOWN'
    else:
        version = git.stdout.read().rstrip('\n')
    # Global text replacement
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    global_dict = dict(DATE=date,
                       VERSION=version,
                       REGION_TABLE_ENTRIES=generateRegionTable(db),
                       REGIONS=generateRegionDocumentation(db))
    text = string.Template(markdown_template).substitute(global_dict)
    with open(filename, 'w') as f:
        f.write(text)
