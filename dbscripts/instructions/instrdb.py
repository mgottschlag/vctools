
import yaml
import os.path
import itertools

class FunctionListEntry:
    name = ''
    brief = ''
    desc = ''
    code_name = ''
    code = ''

class FunctionList:
    def __init__(self):
        self.functions = [];
    name = ''
    brief = ''
    desc = ''
    function_type = ''

class InstructionParameter:
    offset = 0
    size = 0
    name = ''

class Instruction:
    def __init__(self, name, pattern):
        self.mask = []
        self.value = []
        self.parameters = []
        self.name = name
        self.pattern = pattern
        # Parse the pattern
        original_pattern = pattern
        length = 0
        mask = 0
        value = 0
        while pattern != '':
            if pattern[0] == '0':
                pattern = pattern[1:]
                mask = (mask << 1) | 1
                value = value << 1
                length += 1
            elif pattern[0] == '1':
                pattern = pattern[1:]
                mask = (mask << 1) | 1
                value = (value << 1) | 1
                length += 1
            elif pattern[0].isspace():
                pattern = pattern[1:]
                continue
            elif pattern[0].isalpha() or pattern[0] == '_':
                param_offset = len(self.mask) * 16 + length
                # Parse the parameter name
                param_name = pattern[0]
                pattern = pattern[1:]
                while pattern != '' and (pattern[0].isalnum() or
                                         pattern[0] == '_'):
                    param_name += pattern[0]
                    pattern = pattern[1:]
                if pattern == '' or pattern[0] != ':':
                    print('Invalid instruction parameter, expected colon.')
                    print(original_pattern)
                    return
                pattern = pattern[1:]
                # Parse the parameter length
                param_length = ''
                while pattern != '' and pattern[0].isdigit():
                    param_length += pattern[0]
                    pattern = pattern[1:]
                param_length = int(param_length)
                # Create the parameter
                param = InstructionParameter()
                param.offset = param_offset
                param.size = param_length
                param.name = param_name
                self.parameters.append(param)
                # Store masks of finished halfwords
                while length + param_length >= 16:
                    mask = mask << (16 - length)
                    value = value << (16 - length)
                    self.mask.append(mask)
                    self.value.append(value)
                    mask = 0
                    value = 0
                    param_length -= (16 - length)
                    length = 0
                mask = mask << param_length
                value = value << param_length
                length += param_length
            else:
                print('Invalid character in pattern.\n')
                print(original_pattern)
            if length == 16:
                self.mask.append(mask)
                self.value.append(value)
                mask = 0
                value = 0
                length = 0
        if length != 0:
            print(str(length))
            print('Invalid pattern size (not divisible through 16).')
            print(original_pattern)
        if len(self.mask) == 0:
            print('Error, no mask specified.')
            print(original_pattern)
        self.length = len(self.mask)
    name = ''
    pattern = ''
    code = ''
    length = 1

class InstructionDatabase:
    def __init__(self, filename):
        self.function_lists = []
        self.instructions = []
        self.directory = os.path.dirname(filename)
        # Open the YAML file
        dbfile = file(filename, 'r')
        instrdb = yaml.load(dbfile)
        # Parse the file
        self._parseFunctionLists(instrdb['function_lists'])
        self._parseInstructions(instrdb['instructions'])

    def _parseFunctionLists(self, instrdb):
        for name, data in instrdb.iteritems():
            group = FunctionList()
            group.name = name
            if 'brief' in data:
                group.brief = data['brief']
            if 'desc' in data:
                group.desc = data['desc']
            if 'return_type' in data:
                group.return_type = data['return_type']
            if 'parameters' in data:
                group.parameters = data['parameters']
            if 'entries' in data:
                for entry in data['entries']:
                    group.functions.append(self._parseFunction(entry))
            self.function_lists.append(group)

    def _parseFunction(self, db):
        function = FunctionListEntry()
        function.name = db['name']
        if 'brief' in db:
            function.brief = db['brief']
        if 'desc' in db:
            function.desc = db['desc']
        if 'code_name' in db:
            function.code_name = db['code_name']
        function.code = db['code']
        return function

    def _parseInstructions(self, instrdb):
        for instr_data in instrdb:
            instr = Instruction(instr_data['name'], instr_data['pattern'])
            if 'code' in instr_data:
                instr.code = instr_data['code']
            self.instructions.append(instr)

