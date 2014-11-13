CC=gcc
#CFLAGS=-Os ${shell perl -MExtUtils::Embed -e ccopts}
CFLAGS=-g ${shell perl -MExtUtils::Embed -e ccopts}
LDFLAGS=${shell perl -MExtUtils::Embed -e ldopts}

UNAME := $(shell uname)
ifeq ($(UNAME),Linux)
objs = perlxsi.o iston.o
else
objs = istonrc.o perlxsi.o iston.o
endif

iston: $(objs)
	echo "linking... $^ -> $@";
	$(CC) -o $@ $^ $(LDFLAGS)

perlxsi.o: perlxsi.c
	$(CC) -c $(CFLAGS) -o $@ $^

iston.o: iston.c
	$(CC) -c $(CFLAGS) -o $@ $^

perlxsi.c:
	perl -MExtUtils::Embed -e xsinit

istonrc.o: iston.ico iston.rc
	windres iston.rc -o coff -o $@

clean:
	$(RM) *.o perlxsi.c || true
