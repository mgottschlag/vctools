
import datetime
import string
import subprocess

file_template = """
/**
 * VideoCore IV Register Decoder
 *
 * This file was automatically generated from the register database version
 * $VERSION (git) on $DATE.
 * Do not modify!
 */

#include <stdio.h>
#include <string.h>

#define array_size(x) (sizeof(x) / sizeof(x[0]))

struct vc_group {
    const char *name;
    unsigned int address;
    unsigned int size;
    /**
     * Index into "registers".
     */
    unsigned int first_reg;
    unsigned int reg_count;
};

struct vc_register {
    const char *name;
    unsigned int address;
    /**
     * Index into "bitfields".
     */
    unsigned int first_bitfield;
    unsigned int bitfield_count;
};

struct vc_bitfield {
    const char *name;
    unsigned int mask;
    unsigned int shift;
    /**
     * Index into "values".
     */
    unsigned int first_value;
    unsigned int value_count;
};

struct vc_value {
    const char *name;
    unsigned int value;
};

static struct vc_group groups[] = {
$REGISTER_GROUPS
};

static struct vc_register registers[] = {
$REGISTERS
};

static struct vc_bitfield bitfields[] = {
$BITFIELDS
};

static struct vc_value values[] = {
$VALUES
};

/**
 * To speed up lookups, the last resolved register is stored here. If the next
 * call needs the same register, no search for it is necessary, only the address
 * is compared.
 */
static unsigned int register_cache = 0;

static inline int is_in_group(struct vc_group *group, unsigned int address) {
    if (address < group->address) {
        return -1;
    } else if (address >= group->address + group->size) {
        return 1;
    } else {
        return 0;
    }
}

static inline int is_register(struct vc_register *reg, unsigned int address) {
    if (address < reg->address) {
        return -1;
    } else if (address > reg->address) {
        return 1;
    } else {
        return 0;
    }
}

static void search(unsigned int address, int *group, int *reg) {
    *group = -1;
    *reg = -1;
    /* boundaries of the search interval */
    int low;
    int high;
    int center;
    int found;

    /* check the last accessed register */
    if (registers[register_cache].address == address) {
        *reg = register_cache;
        return;
    }
    /* search for the group */
    low = 0;
    high = array_size(groups);
    center = (low + high) / 2;
    while ((found = is_in_group(&groups[center], address)) != 0) {
        if (found == -1) {
            high = center - 1;
        } else {
            low = center + 1;
        }
        if (high < low) {
            /* the group has not been found */
            return;
        }
        center = (low + high) / 2;
    }
    *group = center;
    /* search for the register */
    if (groups[*group].reg_count == 0) {
        /* there are no registers */
        return;
    }
    low = groups[*group].first_reg;
    high = low + groups[*group].reg_count - 1;
    center = (low + high) / 2;
    while ((found = is_register(&registers[center], address)) != 0) {
        if (found == -1) {
            high = center - 1;
        } else {
            low = center + 1;
        }
        if (high < low) {
            /* the register has not been found */
            return;
        }
        center = (low + high) / 2;
    }
    *reg = center;
    /* cache the register to accellerate the next search */
    register_cache = center;
}

struct string_builder {
    char *buffer;
    unsigned int buffer_length;
    unsigned int written;
};
static struct string_builder string_builder_init(char *buffer,
                                                 unsigned int length) {
    struct string_builder builder = { buffer, length, 0 };
    return builder;
}

static void append_string(struct string_builder *builder, const char *str) {
    unsigned int length = strlen(str);
    if (length < builder->buffer_length) {
        memcpy(builder->buffer, str, length);
        builder->buffer += length;
        builder->buffer_length -= length;
    } else {
        memcpy(builder->buffer, str, builder->buffer_length - 1);
        builder->buffer += builder->buffer_length - 1;
        builder->buffer_length = 1;
    }
    builder->buffer[0] = 0;
    builder->written += length;
}
static void append_hex(struct string_builder *builder,
                       unsigned int value,
                       int zero_padded) {
    char str[9] = {0};
    if (zero_padded) {
        snprintf(str, 9, "%08x", value);
    } else {
        snprintf(str, 9, "%x", value);
    }
    append_string(builder, str);
}
static void append_dec(struct string_builder *builder,
                       unsigned int value) {
    char str[11] = {0};
    snprintf(str, 9, "%d", value);
    append_string(builder, str);
}

int vc_decode_register(unsigned int address,
                       char *buffer,
                       unsigned int buffer_length) {
    int group;
    int reg;
    struct string_builder builder = string_builder_init(buffer, buffer_length);

    search(address, &group, &reg);
    if (reg != -1) {
        append_string(&builder, registers[reg].name);
    } else if (group != -1) {
        append_string(&builder, groups[group].name);
        append_string(&builder, " + 0x");
        append_hex(&builder, address - groups[group].address, 0);
    } else {
        append_string(&builder, "0x");
        append_hex(&builder, address, 1);
    }
    return builder.written;
}

static void decode_bitfield(unsigned int *value,
                            struct vc_bitfield *bitfield,
                            struct string_builder *builder) {
    unsigned int i;
    struct vc_value *value_entry;
    unsigned int bf_value;

    bf_value = (*value & bitfield->mask) >> bitfield->shift;
    *value &= ~bitfield->mask;
    /* search for documented values */
    for (i = 0; i < bitfield->value_count; i++) {
        value_entry = &values[bitfield->first_value + i];
        if (bf_value == value_entry->value) {
            if (builder->written != 0) {
                append_string(builder, " | ");
            }
            append_string(builder, value_entry->name);
            return;
        }
    }
    /* just print other values */
    if (bf_value == 0) {
        return;
    }
    if (builder->written != 0) {
        append_string(builder, " | ");
    }
    append_string(builder, bitfield->name);
    if (bitfield->mask != (1u << bitfield->shift)) {
        append_string(builder, "(");
        append_dec(builder, bf_value);
        append_string(builder, ")");
    }
}

int vc_decode_value(unsigned int address,
                    unsigned int value,
                    char *buffer,
                    unsigned int buffer_length) {
    int group;
    int reg_index;
    unsigned int i;
    struct vc_register *reg;
    struct vc_bitfield *bitfield;
    struct string_builder builder = string_builder_init(buffer, buffer_length);

    search(address, &group, &reg_index);
    if (reg_index == -1) {
        append_string(&builder, "0x");
        append_hex(&builder, value, 1);
        return builder.written;
    }
    reg = &registers[reg_index];
    /* go through the list of bitfields and split the value */
    for (i = reg->first_bitfield;
         i < reg->first_bitfield + reg->bitfield_count;
         i++) {
        bitfield = &bitfields[i];
        decode_bitfield(&value, bitfield, &builder);
    }
    if (builder.written == 0) {
        append_string(&builder, "0x");
        append_hex(&builder, value, 0);
    } else if (value != 0) {
        /* append the remaining bits */
        append_string(&builder, " | 0x");
        append_hex(&builder, value, 0);
    }
    return builder.written;
}

"""

class Tables:
    group_table = ''
    group_count = 0
    # Unsorted list, the registers in register_table are sorted
    register_table_tmp = []
    register_table = ''
    register_count = 0
    bitfield_table = ''
    bitfield_count = 0
    value_table = ''
    value_count = 0

class ArrayRange:
    start = 0
    count = 0

def generateValueEntry(value, tables):
    entry = '    { \"' + value.name + '\", ' + str(value.value) + ' },\n'
    tables.value_table += entry
    tables.value_count += 1

def bitfieldMask(low, high):
    return (0xffffffff << low) & (0xffffffff >> (32 - high - 1))

def formatBitfieldEntry(name, mask, shift, first_value, value_count):
    text = '    { \"' + name + '\", ' +  hex(mask) + ', ' + str(shift) + ', '
    text += str(first_value) + ', ' +  str(value_count) + ' },\n'
    return text

def generateBitfieldEntries(bitfield, tables):
    first_value = tables.value_count
    for value in bitfield.values:
        generateValueEntry(value, tables)
    value_count = tables.value_count - first_value
    if value_count == 0:
        first_value = 0
    shift = bitfield.low
    mask = bitfieldMask(bitfield.low, bitfield.high)
    entry = formatBitfieldEntry(bitfield.name, mask, shift, first_value,
                                value_count)
    tables.bitfield_table += entry
    tables.bitfield_count += 1
    pass

def formatRegisterEntry(name, address, first_bitfield, bitfield_count):
    text = '    { \"' + name + '\", ' +  hex(address) + ', '
    text += str(first_bitfield) + ', ' +  str(bitfield_count) + ' },\n'
    return text

def generateRegisterEntries(register, tables, first_bitfield, bitfield_count):
    address = register.offset
    if register.array == False:
        entry = formatRegisterEntry(register.name, address, first_bitfield,
                                    bitfield_count)
        tables.register_table_tmp.append((address, entry))
        tables.register_count += 1
    else:
        for i in range(0, register.count):
            template = string.Template(register.name)
            name = template.substitute(n=i)
            entry = formatRegisterEntry(name, address, first_bitfield,
                                        bitfield_count)
            tables.register_table_tmp.append((address, entry))
            tables.register_count += 1
            address += register.stride

def generateRegisterTypeEntries(regtype, tables):
    first_bitfield = tables.bitfield_count
    for bitfield in regtype.bits:
        generateBitfieldEntries(bitfield, tables)
    bitfield_count = tables.bitfield_count - first_bitfield
    if bitfield_count == 0:
        first_bitfield = 0
    for reg in regtype.registers:
        generateRegisterEntries(reg, tables, first_bitfield, bitfield_count)

def generateGroupEntries(group, tables):
    first_reg = tables.register_count
    tables.register_table_tmp = []
    for regtype in group.regtypes.values():
        generateRegisterTypeEntries(regtype, tables)
    reg_count = tables.register_count - first_reg
    if reg_count == 0:
        first_reg = 0
    else:
        tables.register_table_tmp = sorted(tables.register_table_tmp,
                                           key=lambda x: x[0])
        tables.register_table += ''.join(map(lambda x : x[1],
                                             tables.register_table_tmp))
    tables.group_table += '    { \"' + group.name + '\", ' + hex(group.offset)
    tables.group_table += ', ' + hex(group.size) + ', ' + str(first_reg)
    tables.group_table += ', ' + str(reg_count) + ' },\n'
    tables.group_count += 1

def generateTables(db):
    tables = Tables()
    for group in db.groups:
        generateGroupEntries(group, tables)
    return tables

def generateDecoder(db, filename, vcdbdir):
    # Retrieve the git hash of the version
    git = subprocess.Popen(['git', 'rev-parse', 'HEAD'], cwd=vcdbdir,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if git.wait() != 0:
        version = 'UNKNOWN'
    else:
        version = git.stdout.read().rstrip('\n')
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    # Generate the source code
    tables = generateTables(db)
    global_dict = dict(DATE=date,
                       VERSION=version,
                       REGISTER_GROUPS=tables.group_table,
                       REGISTERS=tables.register_table,
                       BITFIELDS=tables.bitfield_table,
                       VALUES=tables.value_table)
    text = string.Template(file_template).substitute(global_dict)
    with open(filename + '/vcdecoder.c', 'w') as f:
        f.write(text)