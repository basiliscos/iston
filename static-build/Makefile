CC=gcc
CFLAGS=-Os -fdata-sections -ffunction-sections -flto ${shell perl -MExtUtils::Embed -e ccopts}
LDFLAGS=-Os -Wl,--gc-sections -Wl,--strip-all -flto ${shell perl -MExtUtils::Embed -e ldopts}

UNAME=$(shell perl os.pl)
ifeq ($(UNAME),linux)
objs = perlxsi.o  iston.o
else
objs = istonrc.o perlxsi.o iston.o
endif

iston: $(objs)
	echo "linking ($(UNAME)) ... $^ -> $@";
	@$(CC) -o $@ $^ $(LDFLAGS)

perlxsi.o: perlxsi.c
	$(CC) -c $(CFLAGS) -o $@ $^

iston.o: iston.c
	$(CC) -c $(CFLAGS) -o $@ $^

perlxsi.c:
	perl -MExtUtils::Embed -e xsinit

istonrc.o: iston.ico iston.rc
	echo "OS: $(UNAME)"
	windres iston.rc -o coff -o $@

clean:
	$(RM) iston iston.exe *.o perlxsi.c || true
