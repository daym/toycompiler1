%{
#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include "treenode.h"
#include "regalloc.h"

struct structs;
struct bindings {
	struct bindings* next;
	const char* name;
	struct structs* withStruct; /* only != NULL for "with", then contains the struct def for the variable (which is the struct instance) */
};
typedef struct bindings structmembers_t;
struct structs {
	struct structs* next;
	const char* name;
	structmembers_t* members;
};

/* for "with" magical variables */
static unsigned magicalIndex = 0;
static char* getNewMagicalVariable(void) {
        char* result = NULL;
        ++magicalIndex;
        if(asprintf(&result, "$%u", magicalIndex) == -1)
		abort();
        return result;
}

extern void invoke_burm(NODEPTR_TYPE root);

%}
%token func
%token end
%token struct_
%token let
%token return_
%token with
%token in
%token cond
%token id
%token do_
%token or
%token not
%token then
%token LESSGREATER
%token num
%start Program
@autoinh context structs
@autosyn structups fields
@attributes {uint64_t value;} num
@attributes {char* text;} id Funcparamdef Structfielddef
@attributes {struct bindings* fields;} Structfielddefs
@attributes {struct bindings* context; struct structs* structs; } Funcdef Funcparamdefs Condentry Lexpr  
@attributes {struct bindings* context; struct structs* structs; struct structs* structups; } Defs
@attributes {struct bindings* context; struct structs* structs; char* name; treenode* value; } Letentry
@attributes {char* structName; struct bindings* fields;} Structdef
@attributes {struct bindings* context; struct structs* structs; treenode* n;} Expr PrefixedTerm Term Additions Multiplications Disjunctions Stats Stat Stat1 Letbody Condbody OptCallargs Callargs
@attributes {struct bindings* context; struct structs* structs; char* varname; treenode* n; } Withbody
@traversal @postorder check
@traversal @preorder codegen

%{
#include <stdio.h>
#include <stdlib.h>
int yyerror(const char *s) {
    if(fprintf(stderr, "parse error: %s\n", s) < 1)
        exit(3);
    exit(2);
}
static struct bindings* findBindingFlat(struct bindings* root, const char* name) {
	for(; root != NULL; root = root->next) {
		if(strcmp(root->name, name) == 0)
			return root;
	}
	return NULL;
}
static void printBindings(struct bindings* root, int level) {
	for(; root != NULL; root = root->next) {
		printf("%*sbound name: \"%s\"\n", level, "", root->name);
		if(root->withStruct != NULL)
			printBindings(root->withStruct->members, level + 1);
	}
}
static struct bindings* findBinding2(struct bindings* root, const char* name) {
	for(; root != NULL; root = root->next) {
		if(strcmp(root->name, name) == 0)
			return root;
		else if(root->withStruct != NULL) {
			struct bindings* result = findBinding2(root->withStruct->members, name);
			if(result != NULL)
				return result;
		}
	}
	return NULL;
}
/* does not return NULL. Instead terminates. */
static struct bindings* getBinding2(struct bindings* root, const char* name) {
	struct bindings* result;
	result = findBinding2(root, name);
	if(result == NULL) {
		(void) fprintf(stderr, "name \"%s\" is not bound.\n", name);
		printBindings(root, 0);
		exit(3);
	}
	return result;
}
static int32_t getBindingsLen(struct bindings* root) {
	return (root == NULL) ? 0 : 1 + getBindingsLen(root->next);
}
/* index from the front. Note: bindings are "backwards". */
static int32_t findBindingIndexFlat(struct bindings* root, const char* name) {
	int32_t i = 0;
	int32_t result = (-1);
	int32_t len = getBindingsLen(root);
	for(; root; root = root->next, ++i) {
		if(strcmp(root->name, name) == 0) {
			result = i;
			break;
		}
	}
	if(result != -1)
		result = len - 1 - result;
	return result;
}
/* recursively checks all "with" bindings. Index from the front. Note: bindings are "backwards". */
static int32_t findBindingIndex2(struct bindings* root, const char* name, const char** structvarname /* output */) {
	int32_t i = 0;
	int32_t result = (-1);
	int32_t len = getBindingsLen(root);
	*structvarname = NULL;
	for(; root; root = root->next, ++i) {
		/* printf("%s %i\n", root->name, i); */
		if(strcmp(root->name, name) == 0) {
			result = i;
			break;
		} else if(root->withStruct != NULL) {
			result = findBindingIndex2(root->withStruct->members, name, structvarname);
			if(result != -1) {
				*structvarname = root->name;
				return result;
			}
		}
	}
	if(result != -1)
		result = len - 1 - result;
	return result;
}
/* recursively checks all "with" bindings */
static int32_t getBindingIndex2(struct bindings* root, const char* name, const char** structvarname /* output */) {
	int32_t result = findBindingIndex2(root, name, structvarname);
	if(result == (-1)) {
		(void) fprintf(stderr, "name \"%s\" is not bound (note: index).\n", name);
		printBindings(root, 0);
		exit(3);
	}
	return result;
}
/* returns index of a newly inserted variable. Basically would have to do nothing at all except return the highest index. */
static int32_t getBindingIndex0(struct bindings* root, const char* name) {
	assert(strcmp(root->name, name) == 0);
	const char* sv;
	return getBindingIndex2(root, name, &sv);
}
static struct bindings* bind(struct bindings* next, const char* name) {
	struct bindings* result;
	if(findBinding2(next, name) != NULL) {
		(void) fprintf(stderr, "name \"%s\" has already been bound.\n", name);
		exit(3);
	}	
	result = (struct bindings*) calloc(1, sizeof(struct bindings));
	if(result == NULL) {
		(void) fprintf(stderr, "out of memory\n");
		exit(3);
	}
	result->next = next;
	result->name = name;
	result->withStruct = NULL;
	return result;
}
#define bindField bind
static struct structs* findStructdef(struct structs* root, const char* name) {
	for(; root; root = root->next)
		if(strcmp(root->name, name) == 0)
			return root;
	return NULL;
}
/* does not return NULL */
static struct structs* getStructdef(struct structs* root, const char* name) {
	struct structs* result;
	result = findStructdef(root, name);
	if(result == NULL) {
		(void) fprintf(stderr, "struct name \"%s\" is not bound.\n", name);
		exit(3);
	}
	return result;
}
static struct structs* bindStructdef(struct structs* next, const char* name, structmembers_t* members) {
	struct structs* result;
	if(findStructdef(next, name) != NULL) {
		(void) fprintf(stderr, "struct name \"%s\" has already been declared.\n", name);
		exit(3);
	}
	result = (struct structs*) calloc(1, sizeof(struct structs));
	if(result == NULL) {
		(void) fprintf(stderr, "out of memory\n");
		exit(3);
	}
	result->next = next;
	result->name = name;
	result->members = members;
	return result;
}
static struct bindings* bindStructfield(struct bindings* next, struct bindings* fields) {
	return (fields == NULL) ? next : bind(bindStructfield(next, fields->next), fields->name);
}
static struct bindings* bindStructContents(struct bindings* next, struct structs* structs, const char* structname) {
	struct structs* structs1 = getStructdef(structs, structname);
	return bindStructfield(next, structs1->members);
}
/* for "with". Binds struct instance. */
static struct bindings* bindStructInstance(struct bindings* next, struct structs* structs, const char* structname, const char* varname) {
	struct structs* structs1 = getStructdef(structs, structname);
	bindStructContents(next, structs, structname); /* make sure to check for struct fields that would shadow parameters. */
	struct bindings* result = bind(next, varname);
	result->withStruct = structs1;
	return result;
}
/* implement requirement of globally unique field names */
static int64_t getAnyFieldBindingIndex(struct structs* structs, const char* name);
static struct structs* verifyStructs(struct structs* structs) {
	struct bindings* allFields = NULL;
	struct structs* xstructs;
	for(xstructs = structs; xstructs != NULL; xstructs = xstructs->next) {
		struct bindings* fields;
		for(fields = xstructs->members; fields != NULL; fields = fields->next) {
			allFields = bind(allFields, fields->name);
		}
	}
	return structs;
}

/* the *AnyFieldBinding* functions check all the structs for an element with the given name. */
static struct bindings* findAnyFieldBinding(struct structs* structs, const char* name) {
	struct structs* xstructs;
	for(xstructs = structs; xstructs != NULL; xstructs = xstructs->next) {
		struct bindings* binding;
		binding = findBindingFlat(xstructs->members, name);
		if(binding != NULL)
			return binding;
	}
	return NULL;
}
static struct bindings* getAnyFieldBinding(struct structs* structs, const char* name) {
	struct bindings* result;
	result = findAnyFieldBinding(structs, name);
	if(result == NULL) {
		(void) fprintf(stderr, "field name \"%s\" is not bound.\n", name);
		exit(3);
	}
	return result;
}
/* checks all the structs for an element with the given name. Then determine the index of the entry relative to the beginning of the struct. */
static int64_t getAnyFieldBindingIndex(struct structs* structs, const char* name) {
	struct structs* xstructs;
	for(xstructs = structs; xstructs != NULL; xstructs = xstructs->next) {
		int64_t result = findBindingIndexFlat(xstructs->members, name);
		if(result != -1) {
			/* printf("index of %s in %s is %d\n", name, xstructs->name, (int) result); */
			return result;
		}
	}
	(void) fprintf(stderr, "field name \"%s\" is not bound.\n", name);
	exit(3);
}

static treenode* readVarN(struct bindings* context, const char* name) {
	const char* structvarname = NULL;
	int32_t index = getBindingIndex2(context, name, &structvarname);
	if(structvarname != NULL) {
		treenode* structinst = readVarN(context, structvarname);
		return soperationN(DEREF, soperationN(ADD, structinst, immediateN(8*index)), NULL);
	} else
		return registerNByIndex(index);
}
static treenode* writeVarN(struct bindings* context, const char* name, treenode* value) {
	const char* structvarname = NULL;
	int32_t index = getBindingIndex2(context, name, &structvarname);
	if(structvarname != NULL) {
		treenode* structinst = readVarN(context, structvarname);
		return soperationN(WDEREF, soperationN(ADD, structinst, immediateN(8*index)), value);
	} else 
		return soperationN(ASSIGN, registerNByIndex(index), value);
}
static treenode* callargN(treenode* n, treenode* next) {
	return soperationN(CALLARGS, n, next);
}
static treenode* callN(struct bindings* context, treenode* target, treenode* args) {
	return soperationN(CALL, immediateN(getBindingsLen(context)), soperationN(CALLCFG, target, args));
}

%}
%%

Program: Defs @{ @i @Defs.context@ = NULL;
                 @i @Defs.structs@ = verifyStructs(@Defs.structups@);
                 @codegen printf(".text\n"); @}
       ;

Defs: /* empty */ @{ @i @Defs.0.structups@ = NULL; @}
    | Funcdef ';' Defs @{ @i @Defs.0.structups@ = @Defs.1.structups@; @}
    | Structdef ';' Defs @{ @i @Defs.0.structups@ = bindStructdef(@Defs.1.structups@, @Structdef.structName@, @Structdef.fields@); @}
    ;

Structfielddef: id @{ @i @Structfielddef.text@ = @id.text@; @}
              ;

Structfielddefs: /* empty */ @{ @i @Structfielddefs.fields@ = NULL; @}
               | Structfielddefs Structfielddef @{ @i @Structfielddefs.0.fields@ = bindField(@Structfielddefs.1.fields@, @Structfielddef.text@); @}
               ;

Structdef: struct_ id ':' /* Strukturname */ Structfielddefs end @{ @i @Structdef.structName@ = @id.text@; 
                                                                    @i @Structdef.fields@ = @Structfielddefs.fields@; @}
         ;

Funcparamdef: id @{ @i @Funcparamdef.text@ = @id.text@; @}
            ;

Funcparamdefs: ')' Stats end @{ @codegen allocArgRegs(getBindingsLen(@Funcparamdefs.0.context@)); invoke_burm(soperationN(SEQUENCE, @Stats.n@, soperationN(RET, immediateN(0), NULL))); @}
             | Funcparamdef Funcparamdefs @{ @i @Funcparamdefs.1.context@ = bind(@Funcparamdefs.0.context@, @Funcparamdef.text@); @}
             ;

Funcdef: func id '(' Funcparamdefs
       @{ @codegen printf(".globl %s\n.type %s, \100function\n%s:\n", @id.text@, @id.text@, @id.text@); freeAllRegs();
          @codegen @revorder(1) printf("# end fn %s\n", @id.text@); @}
       ;

Stat1: Stat ';' @{ @i @Stat1.n@ = @Stat.n@; @}
     ;

Stats: /* empty */ @{ @i @Stats.n@ = sentinelN(); @}
     | Stat1 Stats @{ @i @Stat1.context@ = @Stats.0.context@; 
                      @i @Stats.1.context@ = @Stat1.context@;
                      @i @Stats.0.n@ = soperationN(SEQUENCE, @Stat1.n@, @Stats.1.n@); @}
     ;

Condbody: /* empty */ @{ @i @Condbody.n@ = sentinelN(); @}
        | Expr then Stats end ';' Condbody @{ @i @Expr.context@ = @Condbody.0.context@;
                                              @i @Stats.context@ = @Expr.context@; 
                                              @i @Condbody.0.n@ = iteN(@Expr.n@, @Stats.n@, @Condbody.1.n@);
                                              @i @Condbody.1.context@ = @Stats.context@; @}
        ;

Letentry: id '=' Expr ';' @{ @i @Letentry.name@ = @id.text@; 
                             @i @Expr.context@ = @Letentry.context@;
                             @i @Expr.structs@ = @Letentry.structs@;
                             @i @Letentry.value@ = @Expr.n@; @}
        ;

Letbody: in Stats @{ @i @Stats.context@ = @Letbody.context@; @i @Letbody.0.n@ = @Stats.n@; @}
       | Letentry Letbody @{ @i @Letentry.context@ = @Letbody.0.context@; 
                             @i @Letbody.1.context@ = bind(@Letbody.context@, @Letentry.name@);
                             @i @Letbody.0.n@ = soperationN(SEQUENCE, soperationN(ASSIGN, registerNByIndex(getBindingIndex0(@Letbody.1.context@, @Letentry.name@)), @Letentry.value@), @Letbody.1.n@); @}
       ;

Withbody: Expr ':' id do_ Stats @{ @i @Expr.context@ = @Withbody.context@;
                                   @i @Withbody.varname@ = getNewMagicalVariable();
                                   @i @Stats.context@ = bindStructInstance(@Withbody.context@, @Withbody.structs@, @id.text@, @Withbody.varname@);
                                   @i @Withbody.n@ = soperationN(SEQUENCE, soperationN(ASSIGN, registerNByIndex(getBindingIndex0(@Stats.context@, @Withbody.varname@)), @Expr.n@), @Stats.n@); @}
        ;

Stat: return_ Expr @{ @i @Stat.n@ = soperationN(RET, @Expr.n@, NULL); @}
    | cond Condbody end @{ @i @Stat.n@ = @Condbody.n@; @}
    | let Letbody end @{ @i @Stat.n@ = @Letbody.n@; @}
    | with Withbody end @{ @i @Stat.n@ = @Withbody.n@; @}
    | id '=' Expr /* Schreibender Variablenzugriff */ @{ @i @Expr.context@ = @Stat.context@;
                                                         @i @Stat.n@ = writeVarN(@Stat.context@, @id.text@, @Expr.n@);
                                                         @check getBinding2(@Stat.context@, @id.text@); @}
    | Term '.' id /* Schreibender Feldzugriff */ '=' Expr @{ @i @Expr.context@ = @Stat.context@;
                                                             @i @Term.context@ = @Stat.context@;
                                                             @i @Stat.n@ = soperationN(WDEREF, soperationN(ADD, @Term.n@, immediateN(8*getAnyFieldBindingIndex(@Term.structs@, @id.text@))), @Expr.n@);
                                                             @check getAnyFieldBinding(@Stat.structs@, @id.text@); @}
    | Term @{ @i @Stat.n@ = @Term.n@; @}
    ;

Additions: Term @{ @i @Additions.0.n@ = @Term.n@; @}
         | Additions '+' Term @{ @i @Additions.1.context@ = @Additions.0.context@; 
                                 @i @Term.context@ = @Additions.1.context@;
                                 @i @Additions.0.n@ = soperationN(ADD, @Additions.1.n@, @Term.n@); @}
         ;

Multiplications: Term @{ @i @Multiplications.0.n@ = @Term.n@; @}
               | Multiplications '*' Term @{ @i @Multiplications.1.context@ = @Multiplications.0.context@; 
                                             @i @Term.context@ = @Multiplications.1.context@;
                                             @i @Multiplications.0.n@ = soperationN(MUL, @Multiplications.1.n@, @Term.n@); @}
               ;

Disjunctions: Term @{ @i @Disjunctions.0.n@ = @Term.n@; @}
            | Disjunctions or Term @{ @i @Disjunctions.1.context@ = @Disjunctions.0.context@; 
                                      @i @Term.context@ = @Disjunctions.1.context@;
                                      @i @Disjunctions.0.n@ = soperationN(OR, @Disjunctions.1.n@, @Term.n@); @}
            ;

PrefixedTerm: Term @{ @i @Term.context@ = @PrefixedTerm.context@;
                      @i @PrefixedTerm.n@ = @Term.n@; @}
            | not PrefixedTerm @{ @i @PrefixedTerm.1.context@ = @PrefixedTerm.0.context@; 
                                  @i @PrefixedTerm.0.n@ = soperationN(NOT, @PrefixedTerm.1.n@, NULL); @}
            | '-' PrefixedTerm @{ @i @PrefixedTerm.1.context@ = @PrefixedTerm.0.context@; 
                                  @i @PrefixedTerm.0.n@ = soperationN(NEG, @PrefixedTerm.1.n@, NULL); @}
            ;

Expr: Term '+' Additions @{ @i @Term.context@ = @Expr.context@; 
                            @i @Additions.context@ = @Term.context@;
                            @i @Expr.n@ = soperationN(ADD, @Term.n@, @Additions.n@); @}
    | Term '*' Multiplications @{ @i @Term.context@ = @Expr.context@;
                                  @i @Multiplications.context@ = @Term.context@;
                                  @i @Expr.n@ = soperationN(MUL, @Term.n@, @Multiplications.n@); @}
    | Term or Disjunctions @{ @i @Term.context@ = @Expr.context@;
                              @i @Disjunctions.context@ = @Term.context@;
                              @i @Expr.n@ = soperationN(OR, @Term.n@, @Disjunctions.n@); @}
    | Term '>' Term @{ @i @Term.0.context@ = @Expr.context@;
                               @i @Term.1.context@ = @Term.context@;
                               @i @Expr.n@ = soperationN(GT, @Term.0.n@, @Term.1.n@); @}
    | Term LESSGREATER Term @{ @i @Term.0.context@ = @Expr.context@;
                               @i @Term.1.context@ = @Term.context@;
                               @i @Expr.n@ = soperationN(NEQ, @Term.0.n@, @Term.1.n@); @}
    | PrefixedTerm @{ @i @Expr.n@ = @PrefixedTerm.n@; @}
    ;


Callargs: Expr @{ @i @Callargs.0.n@ = callargN(@Expr.n@, sentinelN()); @}
        | Expr ',' Callargs @{ @i @Callargs.1.context@ = @Callargs.0.context@; 
                               @i @Expr.context@ = @Callargs.1.context@;
                               @i @Callargs.0.n@ = callargN(@Expr.n@, @Callargs.1.n@); @}
        ;

OptCallargs: /* empty */ @{ @i @OptCallargs.n@ = sentinelN(); @}
           | Callargs @{ @i @OptCallargs.n@ = @Callargs.n@; @}
           | Callargs ',' @{ @i @OptCallargs.n@ = @Callargs.n@; @}
           ;

Term: '(' Expr ')'  @{ @i @Term.n@ = @Expr.n@; @}
    | num @{ @i @Term.n@ = immediateN(@num.value@); @}
    | Term '.' id @{ @i @Term.1.context@ = @Term.0.context@; 
                     @i @Term.0.n@ = soperationN(DEREF, soperationN(ADD, @Term.1.n@, immediateN(8*getAnyFieldBindingIndex(@Term.0.structs@, @id.text@))), NULL); 
                     @check getAnyFieldBinding(@Term.0.structs@, @id.text@); @}
    | id @{ @i @Term.0.n@ = readVarN(@Term.0.context@, @id.text@);
            @check getBinding2(@Term.context@, @id.text@); @}
    | id '(' OptCallargs ')'  @{ @i @Term.0.n@ = callN(@Term.0.context@, labelN(@id.text@), @OptCallargs.n@); @}
    ;

%%

int main(void) {
        yyparse();
        return 0;
}

