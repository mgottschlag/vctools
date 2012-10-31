
import yaml

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
    name = ''
    offset = 0
    brief = ''
    desc = ''
    access = '?'

class RegisterDatabase:
    """Class which parses a register database file"""

    groups = []

    def __init__(self, filename):
        # Open the YAML file
        mmiofile = file(filename, 'r')
        mmio = yaml.load(mmiofile)
        # Read the data
        self._parseGroup(mmio, '', 0)
        # Sort the groups by offset
        # TODO

    def _parseGroup(self, dblist, prefix, offset):
        # Create the group
        # TODO: Anonymous groups?
        if prefix != '':
            name = prefix + '_' + dblist['name']
        else:
            name = dblist['name']
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
        # Create all registers and subgroups in the group
        if 'bare' in dblist and dblist['bare']:
            prefix = ''
        else:
            prefix = name
        if 'blocks' in dblist:
            for choffset, child in dblist['blocks'].iteritems():
                self._parseGroup(child, prefix, group.offset + choffset)
                pass
        if 'registers' in dblist:
            for choffset, child in dblist['registers'].iteritems():
                self._parseRegister(child, group, prefix,
                                    group.offset + choffset)
                pass
        # Sort the registers by offset
        # TODO
        # Skip empty groups
        print(len(group.registers))
        if len(group.registers) != 0 or group.brief != '' or group.desc != '':
            self.groups.append(group)

    def _parseRegister(self, dblist, group, prefix, offset):
        # Create the register
        localoffset = 0
        if 'offset' in dblist:
            localoffset = dblist['offset']
        if 'name' in dblist:
            localname = dblist['name']
        else:
            localname = "UNK_" + hex(localoffset)
        register = Register()
        register.offset = offset + localoffset
        if prefix != '':
            register.name = prefix + '_' + localname
        else:
            register.name = localname
        if 'brief' in dblist:
            register.brief = dblist['brief']
        if 'desc' in dblist:
            register.desc = dblist['desc']
        group.registers.append(register)
        # TODO
        print('register: ' + register.name)

