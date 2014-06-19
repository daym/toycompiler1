NAME = gesamt

.SUFFIXES:

all: $(NAME)

lexer.o: lexer.c oxout.tab.h treenode.h
	gcc -c lexer.c

lexer.c: oxout.l
	flex -t oxout.l > lexer.c

$(NAME).c oxout.tab.h: oxout.y
	bison -vd oxout.y && mv oxout.tab.c $(NAME).c

oxout.y oxout.l: $(NAME).y $(NAME).l
	ox $(NAME).y $(NAME).l

# iburg
$(NAME): $(NAME).o lexer.o $(NAME)_iburg.o treenode.o regalloc.o
	gcc -o $(NAME) $^ -lfl

$(NAME).o: $(NAME).c treenode.h regalloc.h
	gcc -c -DUSE_IBURG $(NAME).c -o $(NAME).o

$(NAME)_iburg.o: $(NAME)_iburg.c treenode.h regalloc.h
	gcc -c -DUSE_IBURG -DBURM $(NAME)_iburg.c -g3 -Wall

$(NAME)_iburg.c: $(NAME).bfe treenode.h regalloc.h
	./bfe < $(NAME).bfe | ../iburg-bison/iburg > $(NAME)_iburg.c.new && mv $(NAME)_iburg.c.new $(NAME)_iburg.c

treenode.o: treenode.c treenode.h
	gcc -c -DUSE_IBURG $< -o $@ -g3 -Wall

regalloc.o: regalloc.c regalloc.h
	gcc -c -DUSE_IBURG $< -o $@ -g3 -Wall

clean:
	rm -f $(NAME)_iburg.c *.o oxout.* *.output $(NAME) *~ core
	rm -f testmain

check: $(NAME)
	cat TEST1 && $(NAME) < TEST1
	cat TEST2 && $(NAME) < TEST2
	cat TEST3 && $(NAME) < TEST3
