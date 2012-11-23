
import subprocess
import datetime
import string

latex_template = """
\\documentclass[a4paper,10pt]{scrreprt}
\\usepackage[utf8]{inputenc}

\\sloppy

\\usepackage[endianness=big]{bytefield}
\\usepackage{hyperref}
\\usepackage{fullpage}
\\usepackage{tabularx}

\\makeatletter
\\newcommand\\cellwidth{\\TX@col@width}
\\makeatother

\\title{Totally Unofficial VideoCore MMIO Reference}
\\author{}

\\begin{document}

\\maketitle

\\refstepcounter{chapter}
\\addcontentsline{toc}{chapter}{\\protect\\numberline{\\thechapter}\\contentsname}
\\tableofcontents

\\chapter{Introduction}

TBD: What is this document?

This document was automatically generated on $DATE from the videocore
register database, git commit $VERSION.

\\chapter{Register Documentation}

\\section{List of MMIO Regions}

\\begin{center}
\\begin{tabular}{|l|l|l|l|}
\\hline
Address & Size & Name & Description\\\\
\\hline
$REGION_TABLE_ENTRIES
\\hline
\\end{tabular}
\\end{center}


$REGIONS

\\end{document}
"""

latex_region_table_template = """
\\texttt{$REGION_ADDRESS} & \\texttt{$REGION_SIZE} & \\texttt{$REGION_NAME} &
$REGION_BRIEF \\\\"""

latex_region_template = """
\\section{\\texttt{$REGION_NAME}: $REGION_BRIEF}

\\subsection{Overview}

\\subsubsection*{Description:}

$REGION_DESC

\\subsubsection*{Registers:}

\\begin{center}
\\begin{tabular}{|l|l|l|l|}
\\hline
Address & Access & Name & Description\\\\
\\hline
$REGISTER_TABLE_ENTRIES
\\hline
\\end{tabular}
\\end{center}

$REGISTERS

"""

latex_register_table_template = """
\\texttt{$REGISTER_ADDRESS} & $REGISTER_ACCESS & \\texttt{$REGISTER_NAME} & \
$REGISTER_BRIEF \\\\"""

latex_register_template = """
\\subsection{$REGISTER_TYPE_CAPTION}

\\begin{tabular}{lll}
$REGISTER_TYPE_LIST
\\end{tabular}

\\begin{center}
\\begin{bytefield}[rightcurly=., rightcurlyspace=0pt]{32}
$BITFIELD_DIAGRAM
\\end{bytefield}
\\end{center}

$REGISTER_TYPE_DESC

$BITFIELD_TABLE

"""

bitfield_table_header = """
\\begin{center}
\\begin{tabularx}{\\textwidth}{|l|l|X|l|}
\\hline
Bits & Name & Description & Access\\\\
\\hline"""

bitfield_table_footer = """
\\end{tabularx}
\\end{center}"""

def escapeLatex(text):
    return text.replace('_', '\\_')

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
    return escapeLatex(access)

def generateBitfieldDiagram(bits, name):
    header = '\\bitheader{'
    lastbit = 31
    content = ''
    for bitfield in bits:
        low = bitfield.low
        high = bitfield.high
        header += str(low) + ', ' + str(high) + ', '
        if high < lastbit:
            # Insert a filler bitfield
            content += '\\bitbox{' + str(lastbit - high) + '}{}'
        size = high - low + 1
        label = escapeLatex(bitfield.name[0:size])
        content += '\\bitbox{' + str(size) + '}{' + label + '}\n'
        lastbit = low - 1
    if lastbit != 0:
        if len(bits) == 0:
            content = ('\\bitbox{' + str(lastbit + 1) + '}{' +
                       escapeLatex(name) + '}' + content)
        else:
            content = '\\bitbox{' + str(lastbit + 1) + '}{}' + content
    header += '0, 31'
    header += '}\\\\\n'
    content += '\\\\\n'
    return header + content

def generateValueTable(values):
    text = '{\\begin{tabularx}{\\cellwidth}{|l|l|X|}\n\\hline\n'
    text += 'Value & Name & Description \\\\\n\\hline\n'
    for value in values:
        text += hex(value.value) + ' & '
        text += escapeLatex(value.name) + ' & '
        text += escapeLatex(value.desc) + ' \\\\\n\\hline\n'
    text += '\\end{tabularx}}\n'
    return text

def generateBitfieldTable(bits):
    if len(bits) == 0:
        return ''
    rows = 0
    text = bitfield_table_header
    for bitfield in bits:
        if rows >= 45:
            text += bitfield_table_footer
            text += bitfield_table_header
            rows = 0;
        low = bitfield.low
        high = bitfield.high
        if low == high:
            text += str(low)
        else:
            text += str(high) + '-' + str(low)
        text += ' & ' + escapeLatex(bitfield.name)
        text += ' & ' + escapeLatex(bitfield.desc)
        if len(bitfield.values) != 0:
            text += '\n' + generateValueTable(bitfield.values)
        text += ' & ' + formatAccess(bitfield.access) + ' \\\\\n\\hline\n'
        rows += len(bitfield.values) + 1
    text += bitfield_table_footer
    return text


def generateRegisterAddress(reg):
    if not reg.array:
        return hex(reg.offset)
    else:
        return hex(reg.offset) + '+i*' + hex(reg.stride)

def generateRegisterName(reg):
    if not reg.array:
        return escapeLatex(reg.name)
    else:
        template = string.Template(reg.name)
        name = template.substitute(n='[0-' + str(reg.count - 1) + ']')
        return escapeLatex(name)

def generateRegisterTable(group):
    text = ''
    template = string.Template(latex_register_table_template)
    for reg in group.registers:
        regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       REGISTER_ACCESS=formatAccess(reg.regtype.access),
                       REGISTER_NAME=generateRegisterName(reg),
                       REGISTER_BRIEF=escapeLatex(reg.brief),
                       REGISTER_DESC=escapeLatex(reg.regtype.desc))
        text += template.substitute(regdict)
    return text;

def generateRegisterTypeDocumentation(regtype):
    if regtype.brief != '':
        caption = escapeLatex(regtype.brief)
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
        reglist += generateRegisterAddress(register) + ' & '
        reglist += '\\texttt{' + generateRegisterName(register) + '} & '
        reglist += escapeLatex(register.brief) + ' \\\\\n'

    template = string.Template(latex_register_template)
    regdict = dict(REGISTER_TYPE_CAPTION=caption,
                   REGISTER_TYPE_LIST = reglist,
                   REGISTER_TYPE_DESC=escapeLatex(regtype.desc),
                   BITFIELD_DIAGRAM=generateBitfieldDiagram(regtype.bits, regtype.name),
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
    template = string.Template(latex_region_table_template)
    for group in db.groups:
        groupdict = dict(REGION_ADDRESS=hex(group.offset),
                         REGION_SIZE=hex(group.size),
                         REGION_NAME=escapeLatex(group.name),
                         REGION_BRIEF=escapeLatex(group.brief),
                         REGION_DESC=escapeLatex(group.desc))
        text += template.substitute(groupdict)
    return text;

def generateRegionDocumentation(db):
    text = ''
    template = string.Template(latex_region_template)
    for group in db.groups:
        if len(group.registers) == 0 and (group.desc.strip() == ''
                                          or group.desc.strip() == 'TBD'):
            # Skip empty groups
            continue
        groupdict = dict(REGION_ADDRESS=hex(group.offset),
                         REGION_SIZE=hex(group.size),
                         REGION_NAME=escapeLatex(group.name),
                         REGION_BRIEF=escapeLatex(group.brief),
                         REGION_DESC=escapeLatex(group.desc),
                         REGISTER_TABLE_ENTRIES=generateRegisterTable(group),
                         REGISTERS=generateRegisterDocumentation(group))
        text += template.substitute(groupdict)
    return text;


def generateLatex(db, filename, vcdbdir):
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
    text = string.Template(latex_template).substitute(global_dict)
    with open(filename, 'w') as f:
        f.write(text)
