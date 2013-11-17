%{/* -*- C -*- */

/*
 * The grammar to convert between the two formats is more complicated
 * than it should be because the syntax used in the EDIF reference
 * manual is not consistent.  For example the definition of `nameDef'
 * is
 *
 *    nameDef ::= identifier | name | rename
 *
 * I feel this should have been defined as
 *
 *    nameDef ::= ( identifier | name | rename )
 *
 * The problem is therefore on detecting the `identifier' is to find out
 * if there are any more parts to the defintion and if there are output
 * the ``one-of'' tag before the `identifier' is output.
 *
 * If it wansn't for this problem, the converter would be even simpler.
 */

#include <assert.h>
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct list_node {
	void *item;
	struct list_node *next;
};

struct list {
	struct list_node *first;
	struct list_node *last;
};

enum edif_type {
	edif_type_string,
	edif_type_literal,
	edif_type_any_number_of,
	edif_type_one_of,
	edif_type_only_one_of,
	edif_type_optional,
	edif_type_list,
	edif_type_variant_list
};

struct edif_node {
	enum edif_type type;
	union {
		const char *string;
		struct list *list;
	} u;
};

/*
 * This is a throw-away program so just assume that no name will be more
 * than 128-characters long.
 */
static char rule_name[128];

static int yyerror(char *);

static const char *strlc(char *s)
{
	char *t= s;
	while (*s != '\0') {
		if (isupper(*s))
			*s= tolower(*s);
		s++;
	}
	return t;
}

static inline void out(const char *str)
{
	printf("%s", str);
}


static inline void space(void)
{
	putchar(' ');
}


static inline struct list_node *node_new(void)
{
	return (struct list_node *)malloc(sizeof(struct list_node));
}


static void list_add_front(struct list * l, void *elem)
{
	struct list_node *new;

	new = node_new();
	new->item = elem;
	new->next = l->first;
	l->first = new;
	if (!l->last)
		l->last= new;
}

static void list_add_back(struct list * l, void *elem)
{
	struct list_node *new;

	new = node_new();
	new->item = elem;
	new->next = (struct list_node *)0;
	if (!l->first)
		l->first = new;
	else
		l->last->next = new;
	l->last = new;
}

static struct list *list_new(void)
{
	struct list *new = (struct list *)malloc(sizeof(*new));

	new->first = 0;
	new->last = 0;
	return new;
}


static struct edif_node *edif_list(enum edif_type t, struct list *l)
{
	struct edif_node *n = malloc(sizeof(*n));
	
	n->type = t;
	n->u.list = l;
	return n;
}

static struct edif_node *edif_string(enum edif_type t, const char *s)
{
	struct edif_node *n = malloc(sizeof(*n));
	
	n->type = t;
	n->u.string = s;
	return n;
}

static struct edif_node *edif_only_one_of(const char *s)
{
	return edif_string(edif_type_only_one_of, s);
}

static struct edif_node *edif_literal(const char *s)
{
	return edif_string(edif_type_literal, s);
}

static void edif_keyword(const char *s, struct list *l)
{
	list_add_front(l, edif_string(edif_type_string, s));
}

static void output_list(struct list *);

static void output_item(struct edif_node *n)
{
	const char *string;
	struct list *list;

	if (!n)
		return;

	string = n->u.string;
	list = n->u.list;
	switch (n->type) {
	case edif_type_string:
		printf(" \"%s\"", string);
		break;
	case edif_type_literal:
		printf(" %s", string);
		break;
	case edif_type_any_number_of:
		printf(" (list");
		output_list(list);
		printf(")");
		break;
	case edif_type_one_of:
		printf(" (or");
		output_list(list);
		printf(")");
		break;
	case edif_type_only_one_of:
		printf(" (unique %s)", string);
		break;
	case edif_type_optional:
		printf(" (optional");
		output_list(list);
		printf(")");
		break;
	case edif_type_list:
	case edif_type_variant_list:
	default:
		fprintf(stderr, "no such node type\n");
		abort();
	}
}

static void output_list(struct list *l)
{
	struct list_node *n;

	n = l->first;
	while (n) {
		output_item(n->item);
		n = n->next;
	}
}



static void output_subrule_list(struct edif_node *first, struct edif_node *rest)
{
	if (rest == 0) {
		output_item(first);
	} else {
		struct list *list;

		list = rest->u.list;
		switch(rest->type) {
		case edif_type_variant_list:
			printf(" (or ");
			output_item(first);
			output_list(list);
			printf(")");
			break;
		case edif_type_list:
			output_item(first);
			output_list(list);
			break;
		default:
			fprintf(stderr, "No such node type\n");
			abort();
		}
	}
}


static void output_keyword_rule(struct list *l)
{
	output_list(l);
}

%}

%union {
	char *s;
	struct list * l;
	struct edif_node *e;
}

%token KW KWS KWE QUOTE END VBAR DEF
%token ORB CRB OCB CCB OSB CSB OAB CAB
%type <e> rule_body_list
%type <l> item_list
%type <l> item_variant
%type <l> keyword_rule
%type <l> body_elements
%type <l> body_element_list
%type <e> body_element
%type <e> literal_string
%type <e> rule_name
%type <e> any_number_of
%type <e> any_number_of_body
%type <l> any_number_of_body_list
%type <e> optional
%type <e> sub_rule_body
%type <l> sub_rule_body_list
%type <e> one_of
%type <e> only_one_of
%type <s> keyword
%%
  
bnf_rules : bnf_rules bnf_rule | bnf_rule ;

bnf_rule :
	KW		{ strncpy(rule_name, yylval.s, sizeof rule_name); }
	DEF
	rule_body	{ out(")"); }
	END
	;

rule_body
	: /* empty */
	| keyword_rule			{ out("\n  (keyword "); out(rule_name); output_keyword_rule($1);}
	| body_element rule_body_list	{ out("\n  (alias "); out(rule_name); output_subrule_list($1, $2);}
	;
  
rule_body_list
	: /* empty */	{ $$ = 0; }
	| item_list	{ $$ = edif_list(edif_type_list, $1); }
	| item_variant	{ $$ = edif_list(edif_type_variant_list, $1); }
	;

item_list
	: item_list body_element	{ $$ = $1; list_add_back($$, $2); }
	| body_element			{ $$ = list_new(); list_add_front($$, $1); }
	;

item_variant
	: item_variant VBAR body_element	{ $$ = $1; list_add_back($$, $3); }
	| VBAR body_element			{ $$ = list_new(); list_add_front($$, $2); }
	;
 

/* keyword_rule represents rule bodies that are of the form
 *
 *  '(' 'acLoad' ... ')'
 *
 * i.e. bodies that start with a keyword name
*/

keyword_rule : KWS QUOTE keyword QUOTE body_elements KWE {$$ = $5; edif_keyword($3, $$);} ;

body_elements
	: /* empty */		{ $$ = list_new(); }
	| body_element_list	{ $$ = $1; }
	;

body_element_list
	: body_element				{ $$ = list_new(); list_add_front($$, $1); }
	| body_element_list body_element	{ $$ = $1; list_add_back($$, $2); }
	;

body_element
	: literal_string	{ $$ = $1; }
	| rule_name		{ $$ = $1; }
	| any_number_of		{ $$ = $1; }
	| optional		{ $$ = $1; }
	| one_of		{ $$ = $1; }
	;

literal_string : QUOTE keyword QUOTE	{$$ = edif_string(edif_type_string, $2);} ;

rule_name : keyword	{$$ = edif_literal($1);} ;

any_number_of : OCB any_number_of_body_list CCB		{ $$ = edif_list(edif_type_any_number_of, $2); } ;

any_number_of_body
	: rule_name		{ $$ = $1; }
	| literal_string	{ $$ = $1; }
	| only_one_of		{ $$ = $1; }
	;

any_number_of_body_list
	: any_number_of_body					{ $$ = list_new(); list_add_front($$, $1); }
	| any_number_of_body_list VBAR any_number_of_body	{ $$ = $1; list_add_back($$, $3);} ;

optional : OSB sub_rule_body_list CSB { $$ = edif_list(edif_type_optional, $2); } ;

sub_rule_body
	: rule_name		{ $$ = $1; }
	| literal_string	{ $$ = $1; }
	;

sub_rule_body_list
	: sub_rule_body				{ $$ = list_new(); list_add_front($$, $1); }
	| sub_rule_body_list VBAR sub_rule_body { $$ = $1; list_add_back($$, $3); } ;

one_of : ORB sub_rule_body_list CRB	{ $$ = edif_list(edif_type_one_of, $2); } ;

only_one_of : OAB keyword CAB		{ $$ = edif_only_one_of($2); } ;

keyword : KW				{ $$ = strdup(yylval.s); } ;

%%


#ifdef BISON
/*
 * When running a parser produced by Bison rather than yacc, setting this
 * variable to 1 (i.e. != 0) means that debugging is turned on.  See the
 * Bison manual for more information.
 */
extern int yydebug;
#endif



/* The error handling routine.  This is deliberately primitive as
 * there should be no errors in the file.  Note that the error is
 * output twice, one to each of the stderr and stdout.  This is
 * because if you output it just to stderr, it is not obvious where in
 * the file the error occured.  Outputting it to both ensures that it
 * will also appear in the output file right after the last valid
 * token.
 */
static int yyerror(char *s)
{
	fprintf(stderr, "ERROR %s\n", s);
	fprintf(stdout, "ERROR %s\n", s);
}

const static const char *start_name = "edif";
const static const char *identifier_name = "identifier";
const static const char *string_name = "stringToken";
const static const char *integer_name = "integerToken";

/*
 * Parses the comment line arguments, and sets various variables
 * depending on the arguments detected.  A fatal error is reported if
 * an unknown option is detected.
 */
static void parse_arguments(int argc, char **argv)
{
	while (--argc != 0) {
		if (argv[argc][0] == '-') {
			switch (argv[argc][1]) {
			case 's':
				start_name = &argv[argc][2];
				break;
			case 'i':
				identifier_name = &argv[argc][2];
				break;
			case 'I':
				integer_name = &argv[argc][2];
				break;
			case 'S':
				string_name = &argv[argc][2];
				break;
			default:
				fprintf(stderr, "no such argument as `%s'\n", argv[argc]);
				exit(EXIT_FAILURE);
			}
		} else {
			fprintf(stderr, "no such argument as `%s'\n", argv[argc]);
			exit(EXIT_FAILURE);
		}
	}
}


int main(int argc, char **argv)
{
	parse_arguments(argc, argv);
	printf("(peg\n");
	printf("  (identifier %s)\n", identifier_name);
	printf("  (string %s)\n", string_name);
	printf("  (integer %s)\n", integer_name);
	printf("\n");
	printf("  (start %s)\n", start_name);
	yyparse();
	printf(")\n");
	return EXIT_SUCCESS;
}
