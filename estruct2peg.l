%{ /* -*- C -*- */

/*
 * This is the lexer for a program that converts the syntax as given
 * in the back of the EDIF v [234] 0 0 manual into the form that is
 * needed to drive pep.
 *
 * As defined there is no obvious way of telling where a rule ends.
 * The method adopted is to assume that all the rules are separated by
 * a blank line.  Thus when a `\n' is read a check is made to see if the
 * next character is also a `\n'.  If it is then it is assumed that the 
 * rule is finished.
 *
 * If the rules don't have a blank line between them then this lexer is
 * going to die badly.
 */

#include "y.tab.h"
%}

ws		[ \t]*
digit		[0-9]
letter		[A-Za-z]
kw		{letter}({letter}|{digit}|_)*
nl		\n
%%

{nl}{nl}	{ return(END); }
{nl}		{ /* do nothing */ }
{ws}		{ /* do nothing */ }
{kw}		{ yylval.s= yytext; return(KW); }
::=		{ return(DEF); }
"'('"		{ return(KWS); }
"')'"		{ return(KWE); }
\'		{ return(QUOTE); }
\|		{ return(VBAR); }
\(		{ return(ORB); }
\)		{ return(CRB); }
\{		{ return(OCB); }
\}		{ return(CCB); }
\[		{ return(OSB); }
\]		{ return(CSB); }
\<		{ return(OAB); }
\>		{ return(CAB); }
%%
