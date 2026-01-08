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

#ifndef UTHREAD_H
#define UTHREAD_H

#ifdef __cplusplus
extern "C" {
#endif
	/* interrupt_handler must be terminated by rts */
	extern int uthread_init(void (*interrupt_handler)(void));
	extern int uthread_deinit(void);

	typedef struct {
		volatile int currentOwner;
		int lockDepth;
	} uthread_mutex_t;

	// TODO: change to return 0 on success
	extern int uthread_mutex_init(uthread_mutex_t *mutex);
	extern int uthread_mutex_lock(uthread_mutex_t *mutex);
	extern int uthread_mutex_unlock(uthread_mutex_t *mutex);

	extern void uthread_interrupt_handler(void);
#ifdef __cplusplus
}
#endif

#endif
