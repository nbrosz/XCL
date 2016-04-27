
go: lex.yy.c xcl.tab.c 
	gcc xcl.tab.c lex.yy.c -lfl -ly -o go 

lex.yy.c: xcl.l
	flex  xcl.l

xcl.tab.c: xcl.y
	bison -dv xcl.y

clean:
	rm -f lex.yy.c 
	rm -f xcl.output
	rm -f xcl.tab.h
	rm -f xcl.tab.c

