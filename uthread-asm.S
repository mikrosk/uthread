/*
 * Copyright 2026 Miro Kropacek <miro.kropacek@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the “Software”), to deal in
 * the Software without restriction, including without limitation the rights to
 * use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 * the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

 #include "symbols.h"

	.global	SYM(uthread_init)
	.global	SYM(uthread_deinit)

	.global	SYM(uthread_interrupt_handler)
	.global	SYM(uthread_switch_to_main)
	.global	SYM(uthread_switch_to_interrupt)

	.global	SYM(uthread_in_interrupt)

	.extern	SYM(_stksize);


	.text

// int uthread_init(void (*interrupt_handler)(void));
SYM(uthread_init):
	moveq		#0,d0
	tst.l		user_interrupt_handler
	bne.b		uthread_init_done

	move.l		(4,sp),user_interrupt_handler

	move.l		SYM(_stksize),-(sp)				| Malloc
	move.w		#72,-(sp)						|
	trap		#1								|
	addq.l		#6,sp							|

	tst.l		d0
	beq.b		uthread_init_done				| fail with d0.l = 0

	move.l		d0,new_isp_bottom				| for Mfree()
	add.l		SYM(_stksize),d0
	move.l		d0,new_isp_top					| new ISP
	moveq		#1,d0

uthread_init_done:
	rts

// int uthread_deinit(void);
SYM(uthread_deinit):
	move.l		new_isp_bottom,d0
	beq.b		uthread_deinit_done				| fail with d0.l = 0

	move.l		d0,-(sp)						| Mfree
	move.w		#73,-(sp)						|
	trap		#1								|
	addq.l		#6,sp							|

	clr.l		new_isp_bottom
	clr.l		new_isp_top
	clr.l		user_interrupt_handler
	moveq		#1,d0

uthread_deinit_done:
	rts

SYM(uthread_interrupt_handler):
	fsave		-(sp)
	fmovem.l	fpcr/fpsr/fpiar,-(sp)
	fmovem.x	fp0-fp7,-(sp)
	movem.l		d0-d7/a0-a6,-(sp)

	// this allows us doing the tricks with old_isp
	bsr.b		execute_handler

	movem.l		(sp)+,d0-d7/a0-a6
	fmovem.x	(sp)+,fp0-fp7
	fmovem.l	(sp)+,fpcr/fpsr/fpiar
	frestore	(sp)+
	rte

execute_handler:
	move.l		sp,old_isp						| old_isp: uthread_interrupt_handler return point
	move.l		new_isp_top,sp

	// TODO: lower the interrupt mask to allow ACIA interrupts

	not.b		SYM(uthread_in_interrupt)		| set
	move.l		user_interrupt_handler,a0
	jsr			(a0)
	not.b		SYM(uthread_in_interrupt)		| clear

	move.l		old_isp,sp						| sp: uthread_interrupt_handler (ISP) or return_to_main (USP)
	rts

// Called from uthread_mutex_lock() when interrupt is blocked
// on a mutex held by main. Saves interrupt context and returns to main.
SYM(uthread_switch_to_main):
	move.l		a0,-(sp)
	lea			saved_regs_from_int_end,a0

	move.l		(sp)+,-(a0)						| a0
	move.l		(sp)+,-(a0)						| pc
	movem.l		d0-d7/a1-a7,-(a0)				| a7 = new_isp
	fmovem.x	fp0-fp7,-(a0)

	// return back to uthread_interrupt_handler
	not.b		SYM(uthread_in_interrupt)		| clear

	move.l		old_isp,sp
	rts

// Called from uthread_mutex_unlock() when main releases
// a mutex the interrupt was waiting for. Saves main context,
// restores interrupt context.
SYM(uthread_switch_to_interrupt):
	move.l		a0,-(sp)
	lea			saved_regs_from_main_end,a0

	move.l		(sp)+,-(a0)						| a0
	move.l		(sp)+,-(a0)						| pc
	movem.l		d0-d7/a1-a7,-(a0)				| a7 = usp
	fmovem.x	fp0-fp7,-(a0)

	// change old_isp's return point
	pea			(return_to_main,pc)				| stored on USP
	move.l		sp,old_isp						| old_isp = USP (unused until now)

	// restore interrupt context
	lea			saved_regs_from_int,a0

	fmovem.x	(a0)+,fp0-fp7
	movem.l		(a0)+,d0-d7/a1-a7				| a7 = new_isp (was USP)
	move.l		(a0)+,-(sp)						| pc for rts below
	move.l		(a0),a0

	not.b		SYM(uthread_in_interrupt)		| set

	// return to uthread_mutex_lock() via new_isp
	rts

return_to_main:
	lea			saved_regs_from_main,a0

	fmovem.x	(a0)+,fp0-fp7
	movem.l		(a0)+,d0-d7/a1-a7				| a7 = USP (should be the same, TODO: verify)
	move.l		(a0)+,-(sp)						| pc for rts below
	move.l		(a0),a0

	// return to AtariMutexInternal::unlock()
	rts


	.bss

	.macro ds.x count
	.space \count * 12
	.endm

saved_regs_from_int:
	ds.x		8								| fp0-fp7
	ds.l		15								| d0-d7/a1-a7
	ds.l		1								| address to return
	ds.l		1								| a0
saved_regs_from_int_end:

saved_regs_from_main:
	ds.x		8								| fp0-fp7
	ds.l		15								| d0-d7/a1-a7
	ds.l		1								| address to return
	ds.l		1								| a0
saved_regs_from_main_end:

new_isp_bottom:
	ds.l		1
new_isp_top:
	ds.l		1
old_isp:
	ds.l		1

user_interrupt_handler:
	ds.l		1

SYM(uthread_in_interrupt):
	ds.b		1
