%{
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include "oxout.tab.h"
#include "treenode.h"
%}
%x COMMENT
decdigit [0-9]
hexdigit [0-9a-fA-F]
%{
static unsigned int parseDigit(const char digit) {
	if(digit >= '0' && digit <= '9')
		return (digit - '0');
	else if(digit >= 'a' && digit <= 'f')
		return (digit - 'a') + 10;
	else if(digit >= 'A' && digit <= 'F')
		return (digit - 'A') + 10;
	else
		abort();
}
static uint64_t parseNumeral(unsigned base, const char* text) {
	uint64_t result = 0;
	_Bool neg = (*text == '-');
	if(neg)
		++text;
	for(; *text != 0 && *text != 'H'; ++text) {
		int64_t nresult = (result * base) + parseDigit(*text);
		if(nresult < result) /* overflow */
			abort();
		result = nresult;
	}		
	if(neg) {
		result = ~result;
		++result;
	}
	return result;
}
static char* stringFromHexNumeral(const char* text) {
	char* result = NULL;
	unsigned int value = parseNumeral(16, text);
	if(asprintf(&result, "num %u\n", value) < 1 || result == NULL)
		exit(3);
	return result;
}
static void raiseError(const char* text) {
	if(fprintf(stderr, "syntax error near \"%s\"\n", text) < 1)
		exit(3);
	exit(1);
}
static char* xstrdup(const char* text) {
	char* result;
	result = strdup(text);
	if(result == NULL) {
		(void) fprintf(stderr, "out of memory\n");
		exit(3);
	}
	return result;
}
%}
%%
struct return struct_;
end return end;
func return func;
return return return_;
with return with;
do return do_;
let return let;
in return in;
cond return cond;
then return then;
not return not;
or return or;
":" return ':';
"(" return '(';
")" return ')';
";" return ';';
"." return '.';
"-" return '-';
"+" return '+';
"*" return '*';
"<>" return LESSGREATER;
">" return '>';
"=" return '=';
"," return ',';
[a-zA-Z][a-zA-Z0-9_]* return id; @{ @id.text@ = xstrdup(yytext); @}
{decdigit}+ return num;  @{ @num.value@ = parseNumeral(10, yytext); @}
{decdigit}{hexdigit}*"H" return num; @{ @num.value@ = parseNumeral(16, yytext); @}
[ \t\n] /* ignore */;
"/*"  { BEGIN COMMENT; }
. raiseError(yytext);
<COMMENT>"*/" { BEGIN INITIAL; }
<COMMENT>"\n" /* ignore */;
<COMMENT>. /* ignore */;
<COMMENT><<EOF>> raiseError("/*");
%%
