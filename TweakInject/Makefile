TARGET  = TweakInject.dylib
OUTDIR ?= .
SRC     = $(wildcard *.c) $(wildcard *.m)
CC      = xcrun -sdk iphoneos gcc -arch arm64e -arch arm64
LDID    = ldid
CFLAGS  = -dynamiclib -framework Foundation

.PHONY: all install clean

all: $(OUTDIR)/$(TARGET)

$(OUTDIR)/$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $@ $^
	$(LDID) -S $@

install: all

clean:
	rm $(TARGET)
