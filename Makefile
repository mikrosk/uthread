TARGET	:= libuthread.a

AR		:= m68k-atari-mintelf-ar
CC		:= m68k-atari-mintelf-gcc

CPU_FLG	:= -m68020-60
CPU_DIR	:= m68020-60

ARFLAGS	:= rcs
ASFLAGS	:= $(CPU_FLG)
CFLAGS	:= -Wall -Wextra -std=c99 -O2 -fomit-frame-pointer $(CPU_FLG)

SYSROOT := $(shell $(CC) -print-sysroot)

$(TARGET): uthread.o uthread-asm.o
	@# process all files at once instead of separetely which the implicit rule does
	@$(RM) $@
	$(AR) $(ARFLAGS) $@ $^

release:
	#$(MAKE) clean && $(MAKE) install CPU_FLG=-m68000 CPU_DIR=.
	$(MAKE) clean && $(MAKE) install CPU_FLG=-m68020-60 CPU_DIR=m68020-60
	#$(MAKE) clean && $(MAKE) install CPU_FLG=-mcpu=5475 CPU_DIR=m5475

install: $(TARGET)
	install -d $(SYSROOT)/usr/include
	install -m 644 uthread.h $(SYSROOT)/usr/include
	install -d $(SYSROOT)/usr/lib/$(CPU_DIR)
	install -m 644 $(TARGET) $(SYSROOT)/usr/lib/$(CPU_DIR)

clean:
	$(RM) -f $(TARGET) *.o

.PHONY: release install clean
