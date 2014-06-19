
all: asma.o

asma: asma.o main.o
	$(CC) -o asma asma.o main.o

asma.o: asma.s asma.h
	$(CC) -o $@ -c asma.s

main.o: main.c asma.h
	$(CC) -o $@ -c main.c -g3

clean:
	rm -f *.o
	rm -f asma

