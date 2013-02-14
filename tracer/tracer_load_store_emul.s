
emulate_load_store:
	lsr r4, r2, 24
	cmp r4, 0x7e
	bne load_store_no_emulation
	cmp r0, 0
	bne load_store_no_emulation
	/* check whether the register is among the emulated registers */
	lea r4, register_value_start
	lea r5, register_value_end
register_search_loop:
	ld r6, (r4)
	beq r6, r2, emulate_register_found
	add r4, 8
	bne r4, r5, register_search_loop
	b load_store_no_emulation

emulate_register_found:
	add r6, r4, 4
	bne r3, 0, emulate_store
emulate_load:
	/* load the register value */
	ld r7, (r6)
	mov r6, r2
	mov r0, r1
	mov r1, r7
	bl store_register
	/* dump the load */
	lea r0, load_label
	bl uart_send_str
	mov r0, '0'
	bl uart_send_char
	ld r0, register_pc
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r6
	bl uart_send_int
	mov r0, r7
	bl uart_send_int_newline
	pop r6-r8, pc
emulate_store:
	mov r8, r2
	/* fetch the value to be stored */
	mov r0, r1
	bl load_register
	mov r7, r0
	/* a write to SDCO+0x0 marks the end of dram initialization */
	mov r0, 0x00200043
	cmp r7, r0
	mov r0, 0x7ee00000
	cmpeq r0, r0, r8
	bne continue_emulation
	bl disable_load_store_emulation
continue_emulation:
	/* dump the store */
	lea r0, store_label
	bl uart_send_str
	mov r0, '0'
	bl uart_send_char
	ld r0, register_pc
	bl uart_send_int
	lea r0, space
	bl uart_send_str
	mov r0, r8
	bl uart_send_int
	mov r0, r7
	bl uart_send_int_newline
	/* search the store value table */
	lea r4, register_store_changes_start
	lea r5, register_store_changes_end
emulate_store_loop:
	ld r3, (r4)
	add r0, r4, 12
	bne r3, r8, emulate_store_no_match
	add r4, 4
	ld r3, (r4)
	bne r3, r7, emulate_store_no_match
	add r4, 4
	ld r7, (r4)
	b emulate_store_loop_end
emulate_store_no_match:
	mov r4, r0
	bne r4, r5, emulate_store_loop
emulate_store_loop_end:
	st r7, (r6)
	pop r6-r8, pc

disable_load_store_emulation:
	mov r0, 0
	st r0, register_emulation_enabled
	rts

	.align 2
/* register load values */
register_value_start:
	.int 0x7e100020, 0x1000
	.int 0x7e102120, 0x10000
	.int 0x7e10203c, 0x180
	.int 0x7e102038, 0x0
	.int 0x7e102034, 0x1d0000
	.int 0x7e102030, 0x0
	.int 0x7e102190, 0x0
	.int 0x7e102220, 0xfec00000
	.int 0x7e101108, 0x300
	.int 0x7e101114, 0x404
	.int 0x7e10202c, 0x0
	.int 0x7e102028, 0x500401
	.int 0x7e102024, 0x4000
	.int 0x7e102020, 0x34
	.int 0x7e102620, 0x5a000002
	.int 0x7e101008, 0x241
	.int 0x7e10100c, 0x1000
	.int 0x7e1010ec, 0x5a013333
	.int 0x7e1010e8, 0x5a000011
	.int 0x7e10006c, 0x5a000001
	.int 0x7e1020d4, 0x5a040000
	.int 0x7e1020d0, 0x5a000000
	.int 0x7e1011ac, 0x5a001000
	.int 0x7e1011a8, 0x4000
	.int 0x7ee00060, 0x1
	.int 0x7ee07048, 0x7
	.int 0x7ee07050, 0x0
	.int 0x7ee07040, 0x11
	.int 0x7ee06080, 0x30
	.int 0x7ee07004, 0x1
	.int 0x7ee06004, 0x1
	.int 0x7ee07018, 0xffff
	.int 0x7ee00004, 0x6e3395
	.int 0x7ee00008, 0xf9
	.int 0x7ee0000c, 0x6000431
	.int 0x7ee00094, 0x10000011
	.int 0x7ee00098, 0x10106000
	.int 0x7ee00014, 0xaf002
	.int 0x7ee00010, 0x8c
	.int 0x7ee00064, 0x3
	.int 0x7ee00000, 0x200042
	.int 0x7ee00090, 0x80000000
	.int 0x7ee06068, 0x223
	.int 0x7ee0704c, 0x223
	.int 0x7ee06070, 0x1
	.int 0x7ee07054, 0x1
	.int 0x7ee06078, 0x2
	.int 0x7ee0705c, 0x2
	.int 0x7ee06058, 0x0
	.int 0x7ee06024, 0x0
	.int 0x7ee06028, 0x0
	.int 0x7ee0602c, 0x10053
	.int 0x7ee06030, 0x0
	.int 0x7ee06034, 0x0
	.int 0x7ee06048, 0x10000
	.int 0x7ee06020, 0x3
register_value_end:

/* register store value changes */
register_store_changes_start:
	.int 0x7e101108, 0x5a000200, 0x200
	.int 0x7e102120, 0x5a001034, 0x1034
	.int 0x7e101108, 0x5a0002aa, 0x2aa
	.int 0x7e101108, 0x5a0002ab, 0x2ab
	.int 0x7e101108, 0x5a0002aa, 0x2aa
	.int 0x7e101008, 0x5a000241, 0x241
	.int 0x7e101008, 0x5a000045, 0x241
	.int 0x7e102190, 0x5a000001, 0x8f08f
	.int 0x7e1011a8, 0x5a004001, 0x4001
	.int 0x7e1011a8, 0x5a004011, 0x4091
	.int 0x7e1011a8, 0x5a024091, 0x34091
	.int 0x7e1011a8, 0x5a030091, 0x30091
	.int 0x7e1011a8, 0x5a010091, 0x91
	.int 0x7e1010e8, 0x5a000011, 0x291
	.int 0x7ee00000, 0x200042, 0x218e42
	.int 0x7ee00090, 0x10000402, 0x90000402
	.int 0x7ee00090, 0x100000ff, 0x900000ff
	.int 0x7ee00064, 0x3, 0x3
	.int 0x7ee00090, 0x3000ff0a, 0xb000ff0a
	.int 0x7ee00090, 0x10000303, 0x90000303
	.int 0x7ee00090, 0x5, 0x80010005
	.int 0x7ee00090, 0x8, 0x80140008
	.int 0x7ee00000, 0x218e4a, 0x214e4a
	.int 0x7e1011a8, 0x5a020091, 0x30091
	.int 0x7e1011a8, 0x5a008081, 0x8001
	.int 0x7e1011a8, 0x5a028001, 0x38001
	.int 0x7e1011a8, 0x5a004001, 0x4001
register_store_changes_end:

