
import subprocess
import datetime
import string
import sys

include_file = """
#ifndef VC4_EMUL_H_INCLUDED
#define VC4_EMUL_H_INCLUDED

#include <stdint.h>

struct vc4_emul;

/**
 * Loads a value from memory. This function is called by the emulator and has
 * to be implemented externally.
 *
 * @param user_data Opaque pointer which has been specified in vc4_emul_init().
 * @param address Address of the memory access.
 * @param size Size of the data to be loaded from memory.
 * @return Data which is read from memory.
 */
uint32_t vc4_emul_load(void *user_data,
                       uint32_t address,
                       int size);
/**
 * Stores a value in the memory. This function is called by the emulator and
 * has to be implemented externally.
 *
 * @param user_data Opaque pointer which has been specified in vc4_emul_init().
 * @param address Address of the memory access.
 * @param size Size of the data to be stored in memory.
 * @param value Value which is stored in memory.
 */
void vc4_emul_store(void *user_data,
                    uint32_t address,
                    int size,
                    uint32_t value);
/**
 * Returns the address of the current interrupt vector table. This function is
 * called by the emulator when an interrupt occurs and has to be implemented
 * externally.
 *
 * @param user_data Opaque pointer which has been specified in vc4_emul_init().
 * @return Address of the interrupt vector table.
 */
uint32_t vc4_emul_get_ivt_address(void *user_data);

/**
 * Initializes a new emulator instance. Initially, all registers are zero.
 *
 * @param user_data Opaque user pointer which can be used for identification
 *                  in vc4_emul_load() and vc4_emul_store().
 * @return New emulator instance.
 */
struct vc4_emul *vc4_emul_init(void *user_data);
/**
 * Destroys an emulator instance which has been previously allocated by
 * vc4_emul_init().
 *
 * @param emul Emulator to be destroyed.
 */
void vc4_emul_free(struct vc4_emul *emul);

void vc4_emul_step(struct vc4_emul *emul);
void vc4_emul_exec(struct vc4_emul *emul, unsigned int steps);

__attribute__((noreturn))
void vc4_emul_interrupt(struct vc4_emul *emul,
                        unsigned int interrupt,
                        const char *reason);

void vc4_emul_set_scalar_reg(struct vc4_emul *emul, int reg, uint32_t value);
uint32_t vc4_emul_get_scalar_reg(struct vc4_emul *emul, int reg);

#endif
"""

file_header = """
/**
 * VideoCore IV Emulator
 *
 * This file was automatically generated from the instruction database version
 * $VERSION (git) on $DATE.
 * Do not modify!
 */

#include "vc4_emul.h"

#include <stdlib.h>
#include <setjmp.h>
#include <assert.h>
#include <stdio.h>
#include <math.h>

struct vc4_emul {
    void *user_data;

    uint32_t scalar_regs[32];
    int pc_changed;

    uint32_t ivt;

    sigjmp_buf exception_handler;
};

struct vc4_emul *vc4_emul_init(void *user_data) {
    struct vc4_emul *emul = calloc(1, sizeof(struct vc4_emul));
    emul->user_data = user_data;
    return emul;
}
void vc4_emul_free(struct vc4_emul *emul) {
    free(emul);
}

void vc4_emul_exec(struct vc4_emul *emul, unsigned int steps) {
    unsigned int i;
    for (i = 0; i < steps; i++) {
        vc4_emul_step(emul);
    }
}

void vc4_emul_exception(struct vc4_emul *emul,
                        unsigned int interrupt,
                        const char *reason) {
    uint16_t instr;
    int i;
    printf("Exception %d: %s\\n", interrupt, reason);
    for (i = 0; i < 32; i++) {
        printf("  r%d = %08x\\n", i, emul->scalar_regs[i]);
    }

    siglongjmp(emul->exception_handler, interrupt + 1);
}

void vc4_emul_interrupt(struct vc4_emul *emul,
                        unsigned int interrupt,
                        const char *reason) {
	int i;
	printf("Interrupt %d: %s\\n", interrupt, reason);
	for (i = 0; i < 32; i++) {
		printf("  r%d = %08x\\n", i, emul->scalar_regs[i]);
	}

    /* TODO */
    assert(0 && "Not implemented.");
}

void vc4_emul_set_scalar_reg(struct vc4_emul *emul, int reg, uint32_t value) {
	assert(reg >= 0 && reg < 32);
	emul->scalar_regs[reg] = value;
}
uint32_t vc4_emul_get_scalar_reg(struct vc4_emul *emul, int reg) {
	assert(reg >= 0 && reg < 32);
	return emul->scalar_regs[reg];
}

"""

global_definitions = """
/* SR status bits */
static uint32_t condition_flags(uint64_t cmp_result) {
   	const unsigned int Z = 8, N = 4, C = 2, V = 1;
    unsigned int status = 0;
    if (cmp_result == 0) {
        status |= Z;
    }
    if (cmp_result & 0x80000000) {
        status |= N;
    }
    if (cmp_result & 0x100000000ull) {
        status |= C;
    }
    if (cmp_result != (int32_t)cmp_result) {
        status |= V;
    }
    return status;
}
#define V(x) ((x & 0x1) != 0)
#define C(x) ((x & 0x2) != 0)
#define N(x) ((x & 0x4) != 0)
#define Z(x) ((x & 0x8) != 0)
/* load/store formats */
#define WORD 0
#define HALFWORD 1
#define BYTE 2
#define SIGNED_HALFWORD 3
/* registers */
#define pc (31)
#define sr (30)
#define sp (25)
#define lr (26)
#define r15 (15)
static uint32_t get_reg(struct vc4_emul *emul, int reg) {
    assert(reg >= 0 && reg <= 31);
    if ((emul->scalar_regs[30] & (1 << 30)) != 0 && reg == 25) {
        reg = 28;
    }
    return emul->scalar_regs[reg];
}
static void set_reg(struct vc4_emul *emul, int reg, uint32_t value) {
    assert(reg >= 0 && reg <= 31);
    if ((emul->scalar_regs[30] & (1 << 30)) != 0 && reg == 25) {
        reg = 28;
    }
    if (reg == 31) {
        emul->pc_changed = 1;
    }
    /*printf("r%d <= %08x\\n", reg, value);*/
    emul->scalar_regs[reg] = value;
}
#define get_reg(reg) get_reg(emul, reg)
#define set_reg(reg, value) set_reg(emul, reg, value)
/* sign extension */
static inline uint32_t sign_extend(uint32_t value, int bits) {
    if (value & (1 << (bits - 1))) {
        return value | ~((1 << bits) - 1);
    } else {
        return value;
    }
}
#define sign_extend_1(x) sign_extend(x, 1)
#define sign_extend_2(x) sign_extend(x, 2)
#define sign_extend_3(x) sign_extend(x, 3)
#define sign_extend_4(x) sign_extend(x, 4)
#define sign_extend_5(x) sign_extend(x, 5)
#define sign_extend_6(x) sign_extend(x, 6)
#define sign_extend_7(x) sign_extend(x, 7)
#define sign_extend_8(x) sign_extend(x, 8)
#define sign_extend_9(x) sign_extend(x, 9)
#define sign_extend_10(x) sign_extend(x, 10)
#define sign_extend_11(x) sign_extend(x, 11)
#define sign_extend_12(x) sign_extend(x, 12)
#define sign_extend_13(x) sign_extend(x, 13)
#define sign_extend_14(x) sign_extend(x, 14)
#define sign_extend_15(x) sign_extend(x, 15)
#define sign_extend_16(x) sign_extend(x, 16)
#define sign_extend_17(x) sign_extend(x, 17)
#define sign_extend_18(x) sign_extend(x, 18)
#define sign_extend_19(x) sign_extend(x, 19)
#define sign_extend_20(x) sign_extend(x, 20)
#define sign_extend_21(x) sign_extend(x, 21)
#define sign_extend_22(x) sign_extend(x, 22)
#define sign_extend_23(x) sign_extend(x, 23)
#define sign_extend_24(x) sign_extend(x, 24)
#define sign_extend_25(x) sign_extend(x, 25)
#define sign_extend_26(x) sign_extend(x, 26)
#define sign_extend_27(x) sign_extend(x, 27)
#define sign_extend_28(x) sign_extend(x, 28)
#define sign_extend_29(x) sign_extend(x, 29)
#define sign_extend_30(x) sign_extend(x, 30)
#define sign_extend_31(x) sign_extend(x, 31)
/* type conversion */
#define to_uint64(x) (uint64_t)(x)
#define to_int64(x) (int64_t)(int32_t)(x)
float int_to_float(uint32_t x) {
    return *(float*)&x;
}
int32_t float_to_int(float x) {
    return *(int32_t*)&x;
}
/* interrupts/exceptions */
#define interrupt(index, reason) vc4_emul_exception(emul, index, reason)
/* fatal errors */
static void error(struct vc4_emul *emul, const char *reason) {
    /* TODO */
    assert(0 && "Not implemented!");
}
#define error(reason) error(emul, reason)
/* memory access functions */
static int size(int format) {
    switch (format) {
        case WORD:
            return 4;
        case HALFWORD:
        case SIGNED_HALFWORD:
            return 2;
        case BYTE:
            return 1;
        default:
            return 0;
    }
}
static uint32_t load(struct vc4_emul *emul,
                     uint32_t address,
                     int format) {
    uint32_t value;
    int format_size = size(format);
    if (address & (format_size - 1)) {
        /* TODO: exception number? */
        interrupt(0, "load: invalid alignment.");
    }
    value = vc4_emul_load(emul->user_data, address, format_size);
    if (format == SIGNED_HALFWORD) {
        value = sign_extend(value, 16);
    }
    return value;
}
static void store(struct vc4_emul *emul,
                  uint32_t address,
                  int format,
                  uint32_t value) {
    int format_size = size(format);
    if (address & (format_size - 1)) {
        /* TODO: exception number? */
        interrupt(0, "load: invalid alignment.");
    }
    vc4_emul_store(emul->user_data, address, format_size, value);
}
#define load(address, format) load(emul, address, format)
#define store(address, format, value) store(emul, address, format, value)
/* push/pop */
static void push(struct vc4_emul *emul, uint32_t value) {
    set_reg(sp, get_reg(sp) - 4);
    store(get_reg(sp), WORD, value);
}
static uint32_t pop(struct vc4_emul *emul) {
    uint32_t value = load(get_reg(sp), WORD);
    set_reg(sp, get_reg(sp) + 4);
    return value;
}
#define push(x) push(emul, x)
#define pop() pop(emul)

static void illegal_instruction(struct vc4_emul *emul, uint16_t *instr) {
    interrupt(0, "illegal instruction");
}

typedef void (*instruction_function)(struct vc4_emul *emul, uint16_t *instr);
"""

step_function = """
void vc4_emul_step(struct vc4_emul *emul) {
    uint16_t instr[3];
    uint32_t old_pc;
    uint32_t old_sr = emul->scalar_regs[25];
    int instr_size = 2;
    /* handle exceptions which occur during execution */
    int exception_index = sigsetjmp(emul->exception_handler, 0);
    if (exception_index != 0) {
        uint32_t ivt = vc4_emul_get_ivt_address(emul->user_data);
        uint32_t int_stack = emul->scalar_regs[28];
        printf("Exception %d\\n", exception_index);
        /* increment pc */
        instr[0] = load(get_reg(pc), HALFWORD);
        set_reg(pc, get_reg(pc) + 2);
        if (instr[0] & 0x8000) {
            set_reg(pc, get_reg(pc) + 2);
            if (instr[0] > 0xe000) {
                set_reg(pc, get_reg(pc) + 2);
            }
        }
        /* push pc and sr onto the stack */
        store(int_stack - 4, WORD, get_reg(pc));
        store(int_stack - 8, WORD, get_reg(sr));
        emul->scalar_regs[28] = int_stack - 8;
        /* load new pc and sr */
        set_reg(pc, load(ivt + (exception_index - 1) * 4, WORD));
        /* TODO: correct bit? */
        set_reg(sr, get_reg(sr) | (1 << 30));
        return;
    }
    /* fetch the instruction */
    emul->pc_changed = 0;
    old_pc = get_reg(pc);
    instr[0] = load(get_reg(pc), HALFWORD);
    if (instr[0] & 0x8000) {
        instr[1] = load(get_reg(pc) + 2, HALFWORD);
        instr_size = 4;
        if (instr[0] > 0xe000) {
            instr[2] = load(get_reg(pc) + 4, HALFWORD);
            instr_size = 6;
        }
    }
    /* switch r25 to r28 if necessary */
    /* TODO */
    /* decode and execute the instruction */
    if (get_reg(sr) & (1 << 30)) {
        uint32_t old_sp = emul->scalar_regs[25];
        emul->scalar_regs[25] = emul->scalar_regs[28];
        decode_instruction(emul, instr);
        emul->scalar_regs[25] = old_sp;
    } else {
        decode_instruction(emul, instr);
    }
    /* increase the program counter */
    if (emul->pc_changed == 0) {
        set_reg(pc, get_reg(pc) + instr_size);
    }
}

"""

decoder_count = 0

max_decoder_length = 4

def is_decoder_necessary(instructions, bits_handled):
    if len(instructions) == 0:
        return False;
    if len(instructions) > 1:
        return True;
    instruction = instructions[0]
    first_word = bits_handled // 16
    for i in range(first_word, instruction.length):
        mask = instruction.mask[i]
        if i == first_word:
            mask &= 0xffff >> (bits_handled % 16)
        if mask != 0:
            return True
    return False

class Decoder:
    def __init__(self, instructions, bits_handled):
        # Create a new unique decoder name
        global decoder_count
        self.name = 'decoder_' + str(decoder_count)
        decoder_count += 1
        # Create the decoder tables
        self.generateDecoder(instructions, bits_handled)

    def generateDecoder(self, instructions, bits_handled):
        word = bits_handled // 16
        for instruction in instructions:
            if word >= instruction.length:
                print('Error, multiple instructions with the same pattern!')
                print(instruction.pattern)
                sys.exit(-1)
        word_offset = bits_handled % 16
        word_mask = 0xffff >> word_offset
        # Find the first bit to be checked
        high_bit = 0 
        for instruction in instructions:
            value = instruction.mask[word] & word_mask
            high_bit = max(high_bit, value.bit_length())
        if high_bit == 0:
            # Continue at the next word
            bits_handled = (word + 1) * 16
            return self.generateDecoder(instructions, bits_handled)
        high_mask = (1 << high_bit) - 1
        low_bit = max(high_bit - max_decoder_length, 0)
        low_mask = (1 << low_bit) - 1
        word_mask = high_mask ^ low_mask
        # Find the number of bits to be checked
        low_bit = high_bit
        for instruction in instructions:
            value = instruction.mask[word] & word_mask
            low_bit = min(low_bit, (value & -value).bit_length() - 1)
        if low_bit < 0:
            print('Error, multiple instructions with colliding patterns:')
            for instruction in instructions:
                print(instruction.pattern)
            sys.exit(-1)
        low_mask = (1 << low_bit) - 1
        word_mask = high_mask ^ low_mask
        # Create instruction lists
        table_size = (high_mask + 1) / (low_mask + 1)
        bits_handled = word * 16 + 16 - low_bit
        instruction_table = []
        for i in range(table_size):
            instruction_table.append([])
            value = i * (low_mask + 1)
            for instruction in instructions:
                if instruction.mask[word] & value == instruction.value[word] & word_mask:
                    instruction_table[i].append(instruction)
        # Recursively create more decoder tables where necessary
        decoder_table = []
        text = ''
        for i in range(table_size):
            if is_decoder_necessary(instruction_table[i], bits_handled):
                found = False
                for j in range(i):
                    if instruction_table[i] == instruction_table[j]:
                        decoder_table.append(decoder_table[j])
                        found = True
                        break
                if found:
                    continue
                decoder_table.append(Decoder(instruction_table[i],
                                             bits_handled))
                text += decoder_table[i].text + '\n'
            else:
                decoder_table.append(None)
        # Create the decoder
        text += 'static instruction_function ' + self.name + '_table[] = {\n'
        for i in range(table_size):
            if decoder_table[i] is not None:
                text += '    ' + decoder_table[i].name + ',\n'
            elif instruction_table[i] != []:
                text += '    ' + instruction_table[i][0].function_name + ',\n'
            else:
                text += '    illegal_instruction,\n'
        text += '};\n\n'
        text += 'static void ' + self.name
        text += '(struct vc4_emul *emul, uint16_t *instr) {\n'
        text += '    ' + self.name + '_table[(instr[' + str(word) + '] & '
        text += hex(word_mask) + ') >> ' + str(low_bit) + '](emul, instr);\n'
        text += '}\n\n'
        # TODO
        self.text = text

    word = 0
    offset = 0
    size = 0
    name = ''
    text = ''

def indent_instruction(code):
    return '\n'.join("        " + line for line in code.splitlines())

def generateEmulator(db, filename, include_filename, vcdbdir):
    # Generate the include file
    with open(include_filename, 'w') as f:
        f.write(include_file)
    # Retrieve the git hash of the version
    git = subprocess.Popen(['git', 'rev-parse', 'HEAD'], cwd=vcdbdir,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if git.wait() != 0:
        version = 'UNKNOWN'
    else:
        version = git.stdout.read().rstrip('\n')
    # Generate the file header
    date = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    global_dict = dict(DATE=date,
                       VERSION=version)
    text = string.Template(file_header).substitute(global_dict)
    # Generate some global definitions needed in all functions
    text += global_definitions + '\n'
    # Generate function auxiliary function definitions
    for group in db.function_lists:
        if len(group.functions) == 0:
            continue
        if group.brief != '' or group.desc != '':
            text += '/*\n'
            if group.brief != '':
                text += group.brief + '\n'
                if group.desc != '':
                    text += '\n'
            if group.desc != '':
                text += group.desc
            text += '*/\n\n'
        for function in group.functions:
            function_code = function.code.split('(', 1)
            text += 'static ' + function_code[0] + '(struct vc4_emul *emul, '
            text += function_code[1] + '\n'
        text += 'static ' + group.return_type + ' (*' + group.name
        text += '_table[])(struct vc4_emul *emul, ' + group.parameters
        text += ') = {\n'
        for function in group.functions:
            text +='\t' + function.name + ',\n'
        text += '};\n\n'
        param_count = len(group.parameters.split(','))
        parameters = ','.join(map(lambda x : 'p' + str(x), range(param_count)))
        text += '#define ' + group.name + '(index, ' + parameters + ') '
        text += group.name + '_table[index](emul, ' + parameters + ')\n\n'
    # Generate the instruction implementation
    text += '/* instructions */\n\n'
    for i in range(len(db.instructions)):
        instr = db.instructions[i]
        instr.function_name = 'instruction_' + str(i)
        text += 'static void ' + instr.function_name
        text += '(struct vc4_emul *emul, uint16_t *instr) {\n'
        if instr.code != '':
            # Declare and compute the parameters
            for parameter in instr.parameters:
                if parameter.name[0] == 'R':
                    text += '    int ' + parameter.name + ' = '
                else:
                    text += '    uint32_t ' + parameter.name + ' = '
                first_word = parameter.offset // 16
                last_word = (parameter.offset + parameter.size - 1) // 16
                for word in range(first_word, last_word + 1):
                    if word != first_word:
                        text += ' | '
                    if word == first_word:
                        first_bit = parameter.offset % 16
                    else:
                        first_bit = 0
                    if word == last_word:
                        last_bit = (parameter.offset + parameter.size - 1) % 16 + 1
                        left_shift = 0
                    else:
                        last_bit = 16
                        left_shift = parameter.offset + parameter.size - (word + 1) * 16
                    mask = (0xffff >> first_bit) ^ (0xffff >> last_bit)
                    shift = 16 - last_bit - left_shift
                    if shift != 0:
                        text += '('
                    if mask != 0xffff:
                        text += '('
                    if word != last_word:
                        text += '(uint32_t)'
                    text += 'instr[' + str(word) + ']'
                    if mask != 0xffff:
                        text += ' & ' + hex(mask) + ')'
                    if shift < 0:
                        text += ' << ' + str(-shift) + ')'
                    elif shift > 0:
                        text += ' >> ' + str(shift) + ')'
                text += ';\n'
            # Insert the actual instruction implementation
            text += '    {\n' + indent_instruction(instr.code) + '\n    }\n'
            for parameter in instr.parameters:
                if parameter.name[0] == 'R':
                    text += '    #undef ' + parameter.name + '\n'
        else:
            text += '    error("Instruction not specified!");\n'
        text += '}\n\n'
    # Generate the instruction decoder
    text += '/* decoder */\n\n'
    decoder = Decoder(db.instructions, 0)
    text += decoder.text
    # Generate the emulator step function
    text += '#define decode_instruction ' + decoder.name + '\n'
    text += step_function
    with open(filename, 'w') as f:
        f.write(text)

