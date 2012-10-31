
import subprocess
import datetime
import string

latex_template = """
\\documentclass[a4paper,10pt]{scrreprt}
\\usepackage[utf8]{inputenc}

\\usepackage[endianness=big]{bytefield}
\\usepackage{hyperref}
\\usepackage{fullpage}

\\title{Totally Unofficial VideoCore MMIO Reference}
\\author{}

\\begin{document}

\\maketitle

\\tableofcontents

\\chapter{Introduction}

TBD: What is this document?

This document was automatically generated on $DATE from the videocore
register database, version $VERSION.

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

\\subsection{Registers}

$REGISTERS

"""

latex_register_table_template = """
\\texttt{$REGISTER_ADDRESS} & $REGISTER_ACCESS & \\texttt{$REGISTER_NAME} &
$REGISTER_BRIEF \\\\"""

latex_register_template = """
\\subsubsection*{$REGISTER_NAME: $REGISTER_BRIEF}

$REGISTER_DESC

\\begin{center}
\\begin{bytefield}[rightcurly=., rightcurlyspace=0pt]{32}
$BITFIELD_DIAGRAM
\\end{bytefield}
\\end{center}



BITFIELDTABLE
"""

def escapeLatex(text):
    return text.replace('_', '\\_')

def generateBitfieldDiagram(reg):
    header = '\\bitheader{'
    lastbit = 0
    content = ''
    for bitfield in reg.bits:
        low = bitfield.low
        high = bitfield.high
        header += str(low) + ', ' + str(high) + ', '
        if low > lastbit:
            # Insert a filler bitfield
            content = '\\bitbox{' + str(low - lastbit) + '}{}' + content
        size = high - low + 1
        label = escapeLatex(bitfield.name[0:size])
        content = '\\bitbox{' + str(size) + '}{' + label + '}\n' + content
        lastbit = high + 1
    if lastbit != 32:
        content = '\\bitbox{' + str(32 - lastbit) + '}{}' + content
    header += '0, 31'
    header += '}\\\\'
    content += '\\\\'
    return header + content

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
        name = template.substitute(n='[0-' + str(reg.count) + ']')
        return escapeLatex(name)

def generateRegisterTable(group):
    text = ''
    template = string.Template(latex_register_table_template)
    for reg in group.registers:
        regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       REGISTER_ACCESS=escapeLatex(reg.access),
                       REGISTER_NAME=generateRegisterName(reg),
                       REGISTER_BRIEF=escapeLatex(reg.brief),
                       REGISTER_DESC=escapeLatex(reg.desc))
        text += template.substitute(regdict)
    return text;

def generateRegisterDocumentation(group):
    text = ''
    template = string.Template(latex_register_template)
    for reg in group.registers:
        regdict = dict(REGISTER_ADDRESS=generateRegisterAddress(reg),
                       REGISTER_ACCESS=escapeLatex(reg.access),
                       REGISTER_NAME=generateRegisterName(reg),
                       REGISTER_BRIEF=escapeLatex(reg.brief),
                       REGISTER_DESC=escapeLatex(reg.desc),
                       BITFIELD_DIAGRAM=generateBitfieldDiagram(reg))
        text += template.substitute(regdict)
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
    # TODO
    pass
