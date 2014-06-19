#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include "treenode.h"
treenode* operationN(int op/*erator*/, treenode* c0, treenode* c1, treenode* c2, const char* regname, uint64_t value, const char* label) {
	treenode* result = malloc(sizeof(treenode));
	if(result == NULL) {
		fprintf(stderr, "error: Out of memory.\n");
		exit(4);
	}
	result->op = op;
	result->kids[0] = c0;
	result->kids[1] = c1;
	result->kids[2] = c2;
	result->regname = regname;
	result->value = value;
	result->label = label;
	return result;
}
treenode* soperationN(int op/*erator*/, treenode* c0, treenode* c1) {
	return operationN(op, c0, c1, NULL, NULL, 0, NULL);
}
treenode* iteN(treenode* c0, treenode* c1, treenode* c2) {
	/* doesn't work in iburg: return operationN(ITE, c0, c1, c2, NULL, 0); */
	return soperationN(SEQUENCE, soperationN(TEST_BOOL, c0, NULL), soperationN(THEN_ELSE, c1, c2));
}
treenode* registerN(const char* regname) {
	return operationN(REG, NULL, NULL, NULL, regname, 0, NULL);
}
treenode * labelN(const char* label) {
	return operationN(LABEL, NULL, NULL, NULL, NULL, 0, label);
}
treenode* sentinelN(void) {
	return soperationN(SENTINEL, NULL, NULL);
}
treenode* immediateN(uint64_t value) {
        return operationN(NUM, NULL, NULL, NULL, NULL, value, NULL);
}

