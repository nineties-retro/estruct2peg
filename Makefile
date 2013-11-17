#
# estruct2peg is a trivial program which is not undergoing active
# development so the Makefile is very simple and not an example of how
# to use Make for larger projects.
#

YACC=yacc -d
LEXLIBS=-ll

LINK.c = $(CC) $(CFLAGS) $(CPPFLAGS) $(LDFLAGS) 

OBJ =	lex.yy.o y.tab.o

estruct2peg:	$(OBJ)
	$(LINK.c) $(OBJ) $(LEXLIBS) -o $@

lex.yy.c:	estruct2peg.l y.tab.h
	$(LEX) estruct2peg.l

y.tab.c y.tab.h:	estruct2peg.y
	$(YACC) estruct2peg.y

clean:
	rm -f lex.yy.o y.tab.o lex.yy.c y.tab.c y.tab.h estruct2peg
