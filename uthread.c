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

#include "uthread.h"

#include <stddef.h>

// private forward declarations
#ifdef __cplusplus
extern "C" {
#endif
	extern void uthread_switch_to_main(void);
	extern void uthread_switch_to_interrupt(void);

	extern void (*uthread_user_interrupt_enable)(void);
	extern void (*uthread_user_interrupt_disable)(void);

	extern volatile char uthread_in_interrupt;
#ifdef __cplusplus
}
#endif

static volatile uthread_mutex_t *blockingMutex = NULL;
static volatile int interruptEnabled = 1;

enum Owner {
	OWNER_NONE = 0,
	OWNER_MAIN = 1,
	OWNER_INTERRUPT = 2
};

int uthread_mutex_init(uthread_mutex_t *mutex) {
	mutex->currentOwner = OWNER_NONE;
	mutex->lockDepth = 0;

	return 0;
}

int uthread_mutex_lock(uthread_mutex_t *mutex) {
	if (uthread_in_interrupt) {
		switch (mutex->currentOwner) {
		case OWNER_MAIN:
			if (blockingMutex)
				return 1;

			blockingMutex = mutex;
			// there is no point in letting the interrupt trigger before the mutex is unlocked
			uthread_user_interrupt_disable();
			interruptEnabled = 0;
			uthread_switch_to_main();
			// this is where uthread_switch_to_interrupt jumps
			// as user code (no interrupt anymore)
			// fall through

		case OWNER_NONE:
			mutex->currentOwner = OWNER_INTERRUPT;
			// fall through

		case OWNER_INTERRUPT:
			mutex->lockDepth++;
			return 0;
		}
	} else {
		switch (mutex->currentOwner) {
		case OWNER_INTERRUPT:
			// TODO !!!!
			return 1;

		case OWNER_NONE:
			if (interruptEnabled)
				uthread_user_interrupt_disable();

			mutex->currentOwner = OWNER_MAIN;
			mutex->lockDepth++;

			if (interruptEnabled)
				uthread_user_interrupt_enable();

			return 0;

		case OWNER_MAIN:
			mutex->lockDepth++;
			return 0;
		}
	}

	return 0;
}

int uthread_mutex_unlock(uthread_mutex_t *mutex) {
	if (mutex->lockDepth > 0) {
		mutex->lockDepth--;

		if (mutex->lockDepth == 0) {
			if (uthread_in_interrupt) {
				mutex->currentOwner = OWNER_NONE;
			} else {
				if (interruptEnabled)
					uthread_user_interrupt_disable();

				mutex->currentOwner = OWNER_NONE;

				if (blockingMutex == mutex) {
					blockingMutex = NULL;
					uthread_switch_to_interrupt();
					// this is where uthread_switch_to_interrupt's return_to_main
					// jumps when finishes interrupt code

					// re-enable again, hopefully we managed to process samples in time
					interruptEnabled = 1;
				}

				// it's ok if TimerA fires now but TODO:
				// - it has to be the proper next one (i.e. code above filled
				//   the log buffer while SDMA finished playing the phys one
				// - it must handle if code above took more than one sample frame:
				//	- two: log/phys are out of sync
				//	- three: log/phys are in sync
				// - we must also handle if TimerA *would* fire JUST NOW but didn't
				//   allow it yet... that's basically missing one frame above
				if (interruptEnabled)
					uthread_user_interrupt_enable();
			}
		}

		return 0;
	}

	return 1;
}
