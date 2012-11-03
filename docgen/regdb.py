
import yaml
import os.path

class RegisterGroup:
    """Class which contains information about one group of registers"""

    def __init__(self):
        self.registers = []
    name = ''
    offset = 0
    size = 0
    brief = ''
    desc = ''

class Register:
    """Class which contains information about a single register"""
    def __init__(self):
        self.bits = []
        self.values = []
    name = ''
    offset = 0
    brief = ''
    desc = ''
    access = '?'
    array = False
    count = 1
    stride = 0

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
        # Create the group
        # TODO: Anonymous groups?
        if prefix != '' and 'name' in dblist:
            name = prefix + '_' + dblist['name']
        elif prefix != '':
            name = prefix
        elif 'name' in dblist:
            name = dblist['name']
        else:
            name = ''
        group = RegisterGroup()
        group.name = name
        group.offset = offset
        if 'offset' in dblist:
            group.offset += dblist['offset']
        if 'size' in dblist:
            group.size = dblist['size']
        if 'brief' in dblist:
            group.brief = dblist['brief']
        if 'desc' in dblist:
            group.desc = dblist['desc']
        hide_group = False
        if 'hide' in dblist:
            hide_group = dblist['hide']
        # Create all registers and subgroups in the group
        if 'bare' in dblist and dblist['bare']:
            prefix = ''
        else:
            prefix = name

        if 'blocks' in dblist:
            for choffset, child in dblist['blocks'].iteritems():
                self._parseGroup(child, prefix, group.offset + choffset, parent,
                                 array_info)
        if 'registers' in dblist:
            for choffset, child in dblist['registers'].iteritems():
                self._parseRegister(child, group, prefix,
                                    group.offset + choffset, parent,
                                    array_info)
        if 'arrays' in dblist:
            for choffset, child in dblist['arrays'].iteritems():
                self._parseArray(child, group, prefix,
                                 group.offset + choffset, parent,
                                 array_info)
        # Sort the registers by offset
        group.registers = sorted(group.registers,
                                 key=lambda register: register.offset)
        # Skip hidden groups
        if parent is None and hide_group == False:
            self.groups.append(group)

    def _parseArray(self, dblist, group, prefix, offset, parent, array_info):
        if array_info != None:
            print("Warning: Nested arrays not supported yet!")
            return
        array = ArrayInfo()
        array.count = dblist['length']
        array.stride = dblist['stride']
        if 'name' in dblist:
            prefix = prefix + '_' + dblist['name']
        if 'block' in dblist:
            self._parseGroup(dblist['block'], prefix, offset, group, array)
        if 'register' in dblist:
            # TODO
            pass
        pass

    def _parseRegister(self, dblist, group, prefix, offset, parent, array_info):
        if dblist == None:
            dblist = {}
        # Create the register
        if 'name' in dblist:
            name = dblist['name']
        else:
            name = "UNK_" + hex(offset - group.offset)
        register = Register()
        register.offset = offset
        if prefix != '':
            register.name = prefix + '_' + name
        else:
            register.name = name
        if 'brief' in dblist:
            register.brief = dblist['brief']
        if 'desc' in dblist:
            register.desc = dblist['desc']
        if 'access' in dblist:
            register.access = dblist['access']
        if array_info != None:
            register.array = True
            register.count = array_info.count
            register.stride = array_info.stride
        if parent != None:
            parent.registers.append(register)
        else:
            group.registers.append(register)
        # Parse the bitfields
        if 'bits' in dblist:
            self._parseBitfields(dblist['bits'], register)
        # If no bitfields are present, create one large field
        if len(register.bits) == 0:
            bitfield = Bitfield()
            bitfield.low = 0
            bitfield.high = 31
            bitfield.name = register.name
            register.bits.append(bitfield)
        register.bits = sorted(register.bits,
                               key=lambda bitfield: bitfield.low)

    def _parseBitfields(self, dblist, register):
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
            register.bits.append(bitfield)
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
