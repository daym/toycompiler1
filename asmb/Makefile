
all: asmb.o

asmb: asmb.o main.o
	$(CC) -o asmb asmb.o main.o

asmb.o: asmb.s asmb.h
	$(CC) -o $@ -c asmb.s

main.o: main.c asmb.h
	$(CC) -o $@ -c main.c -g3

clean:
	rm -f *.o
	rm -f asmb

