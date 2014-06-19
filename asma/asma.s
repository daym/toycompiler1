	.file	"a.c"
	.data
mask:
	.align 16
	.size mask, 16
	.fill 16, 1, 0xFF
	.text
.globl asma
	.type	asma, @function
asma:
	# calculates MAXIMUM of the two arguments and stores it into the third.
	# if (s > t) s else t
	# if (-s < -t) s else t
	# if (255 - s < 255 - t) s else t
.LFB0:
	.cfi_startproc
	# %rdi contains address of first argument.
	# %rsi contains address of second argument.
	# %rdx contains address of third argument.
	# TODO check parameter alignment, use movdqa
	# note: xmm8..xmm15 are caller saved.
	movdqu (%rdi), %xmm8
	movdqu (%rsi), %xmm9
	andnps mask, %xmm8  # xmm8 = ~xmm8 & xmm10
	andnps mask, %xmm9
	pminub %xmm8, %xmm9
	andnps mask, %xmm9
	movdqu %xmm9, (%rdx)
	ret
	.cfi_endproc
.LFE0:
	.size	asma, .-asma
	.ident	"GCC: (Debian 4.4.5-8) 4.4.5"
	.section	.note.GNU-stack,"",@progbits
