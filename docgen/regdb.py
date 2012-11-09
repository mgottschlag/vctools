
import yaml
import os.path
import itertools

class RegisterGroup:
    """Class which contains information about one group of registers"""

    def __init__(self):
        self.registers = []
        self.regtypes = {}
    name = ''
    offset = 0
    size = 0
    brief = ''
    desc = ''

class Register:
    """Class which contains information about a single register"""
    def __init__(self):
        self.values = []
    name = ''
    offset = 0
    brief = ''
    array = False
    count = 1
    stride = 0
    regtype = None

class RegisterType:
    """Class which contains information about multiple equal registers"""
    def __init__(self):
        self.bits = []
        self.registers = []

    localname = ''
    name = ''
    brief = ''
    desc = ''
    access = '?'

class Bitfield:
    def __init__(self):
        self.values = []
    low = 0
    high = 0
    access = '?'
    name = ''
    brief = ''
    desc = ''

class ArrayInfo:
    count = 1
    stride = 0

class RegisterValue:
    value = 0
    name = ''
    desc = ''

def _concatNames(a, b):
    if a == '':
        return b
    if b == '':
        return a
    # If one of the strings contains multiple names, create all combinations
    a_names = a.split('/')
    b_names = b.split('/')
    a_b_prod = itertools.product(a_names, b_names)
    return '/'.join(map(lambda x : x[0] + '_' + x[1], a_b_prod))

class RegisterDatabase:
    """Class which parses a register database file"""

    groups = []
    directory = ''

    def __init__(self, filename):
        self.directory = os.path.dirname(filename)
        # Open the YAML file
        regdbfile = file(filename, 'r')
        regdb = yaml.load(regdbfile)
        # Read the data
        self._parseGroup(regdb, '', 0, None, None)
        # Sort the groups by offset
        self.groups = sorted(self.groups,
                             key=lambda group: group.offset)

    def _parseGroup(self, dblist, prefix, offset, parent, array_info):
        # Check whether this is a link to a different file
        while 'file' in dblist:
            dbfile = file(self.directory + '/' + dblist['file'], 'r')
            dblist = yaml.load(dbfile)
        # Create the group name
        name = ''
        if 'name' in dblist:
            name = dblist['name']
        name = _concatNames(prefix, name)
        if 'offset' in dblist:
            offset += dblist['offset']
        # The "bare" flag defines whether entries will be prefixed
        if 'bare' in dblist and dblist['bare']:
            bare = True
        else:
            bare = False
        hide_group = False
        if 'hide' in dblist:
            hide_group = dblist['hide']
        if parent is None and hide_group == False:
            group = RegisterGroup()
            group.name = name
            group.offset = offset
            if 'size' in dblist:
                group.size = dblist['size']
            if 'brief' in dblist:
                group.brief = dblist['brief']
            if 'desc' in dblist:
                group.desc = dblist['desc']
        else:
            group = parent
        # Create all registers and subgroups in the group
        if 'bare' in dblist and dblist['bare']:
            prefix = ''
        else:
            prefix = name

        if 'types' in dblist:
            for typename, child in dblist['types'].iteritems():
                regtype = self._parseType(child, group, prefix, '')
                group.regtypes[typename] = regtype
        if 'blocks' in dblist:
            for choffset, child in dblist['blocks'].iteritems():
                self._parseGroup(child, prefix, offset + choffset, group,
                                 array_info)
        if 'registers' in dblist:
            for choffset, child in dblist['registers'].iteritems():
                self._parseRegister(child, group, prefix,
                                    offset + choffset, array_info)
        if 'arrays' in dblist:
            for choffset, child in dblist['arrays'].iteritems():
                if array_info != None:
                    print("Warning: Nested arrays not supported yet!")
                    continue
                self._parseArray(child, group, prefix, group.offset + choffset)
        # Skip hidden groups
        if parent is None and hide_group == False:
            self.groups.append(group)
            # Sort the registers by offset
            group.registers = sorted(group.registers,
                                    key=lambda register: register.offset)
            for regtype in group.regtypes.values():
                regtype.registers = sorted(regtype.registers,
                                           key=lambda register: register.offset)
            # Remove unused types
            group.regtypes = dict((k, v) for k, v in group.regtypes.iteritems()
                                             if len(v.registers) != 0)

    def _parseArray(self, dblist, group, prefix, offset):
        array = None
        if dblist['length'] != 1:
            array = ArrayInfo()
            array.count = dblist['length']
            array.stride = dblist['stride']
        name = ''
        if 'name' in dblist:
            name = dblist['name']
        prefix = _concatNames(prefix, name)
        if 'block' in dblist:
            self._parseGroup(dblist['block'], prefix, offset, group, array)
        if 'register' in dblist:
            # TODO
            pass
        pass

    def _parseRegister(self, dblist, group, prefix, offset, array_info):
        if dblist == None:
            dblist = {}
        # Create the register
        if 'name' in dblist:
            name = dblist['name']
        else:
            name = "UNK_" + hex(offset - group.offset)
        register = Register()
        register.offset = offset
        register.name = _concatNames(prefix, name)
        if 'brief' in dblist:
            register.brief = dblist['brief']
        if (array_info != None and (array_info.count != 1 and
                                    not '${n}' in name and
                                    not '$n' in name)):
            register.array = True
            register.count = array_info.count
            register.stride = array_info.stride
        # Parse the register format
        if 'type' in dblist:
            regtype = group.regtypes[dblist['type']]
            regtype.registers.append(register)
        else:
            regtype = self._parseType(dblist, group, prefix, name)
            regtype.registers.append(register)
            group.regtypes[name] = regtype
        register.regtype = regtype
        # Insert the register into the group
        group.registers.append(register)

    def _parseType(self, dblist, group, prefix, name):
        if dblist == None:
            dblist = {}
        regtype = RegisterType()
        if 'name' in dblist:
            name = dblist['name']
        regtype.localname = name
        if prefix != '':
            regtype.name = prefix + '_' + name
        else:
            regtype.name = name
        regtype.name = regtype.name.replace('_${n}', '').replace('_$n', '')
        regtype.name = regtype.name.replace('$n', '')
        #print("Generating type " + regtype.name + " (" + regtype.localname + ")")
        if 'brief' in dblist:
            regtype.brief = dblist['brief']
        if 'desc' in dblist:
            regtype.desc = dblist['desc']
        if 'access' in dblist:
            regtype.access = dblist['access']
        # Parse the bitfields
        if 'bits' in dblist:
            self._parseBitfields(dblist['bits'], regtype)
        regtype.bits = sorted(regtype.bits,
                              key=lambda bitfield: bitfield.low,
                              reverse=True)
        return regtype

    def _parseBitfields(self, dblist, regtype):
        for bitrange, entry in dblist.iteritems():
            bitfield = Bitfield()
            if type(bitrange) is int:
                bitfield.high = bitfield.low = bitrange
            else:
                words = bitrange.split('-')
                if not len(words) == 2:
                    print("Warning: Invalid bit range specification.")
                    return
                bitfield.high = max(int(words[0]), int(words[1]))
                bitfield.low = min(int(words[0]), int(words[1]))
            if 'name' in entry:
                bitfield.name = entry['name']
            else:
                bitfield.name = 'UNK_' + str(bitfield.low)
            if 'brief' in entry:
                bitfield.brief = entry['brief']
            if 'desc' in entry:
                bitfield.desc = entry['desc']
            if 'access' in entry:
                bitfield.access = entry['access']
            if 'values' in entry:
                bitfield.values = self._parseValues(entry['values'])
            regtype.bits.append(bitfield)
            pass

    def _parseValues(self, dblist):
        values = []
        for num_value, entry in dblist.iteritems():
            value = RegisterValue()
            value.value = num_value
            if 'name' in entry:
                value.name = entry['name']
            if 'desc' in entry:
                value.desc = entry['desc']
            values.append(value)
        return values
