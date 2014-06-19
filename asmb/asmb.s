	.file	"a.c"
	.data
zeroes:
	.align 16
	.size mask, 16
	.fill 16, 1, 0x00
	.text
.globl asmb
	.type	asmb, @function
asmb:
.LFB0:
	.cfi_startproc
	# %rdi contains address of first argument.
	# %rsi contains address of second argument.
	# %rdx contains address of third argument.
	# TODO check parameter alignment, use movdqa
	# note: xmm8..xmm15, rdi, rsi are caller saved.
loop1:
	movdqu (%rdi), %xmm8
	movdqu (%rsi), %xmm9
	pminub %xmm8, %xmm9 # xmm9 = Minimum. Includes 0 if any of the operands was 0.
	movdqu %xmm9, (%rdx) # store Minima.
	pcmpeqb zeroes, %xmm9 # find the zeroes (slots in xmm9 will be set 0xFF if zero, 0 otherwise).
	add $16, %rdi
	add $16, %rsi
	add $16, %rdx
	ptest %xmm9, %xmm9 # xmm9 = 0 ?
	jz loop1 # no zeroes found -> loop
	ret
	.cfi_endproc
.LFE0:
	.size	asma, .-asma
	.ident	"GCC: (Debian 4.4.5-8) 4.4.5"
	.section	.note.GNU-stack,"",@progbits
