#include <string.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include "treenode.h"
#include "regalloc.h"
static const char* registerNames[] = {"%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9" };
treenode* registerNByIndex(int64_t index) {
	if(index >= 0 && index < REG_COUNT)
		return registerN(registerNames[index]);
	else {
		fprintf(stderr, "error: Register number out of range.\n");
		exit(4);
	}
}
static _Bool allocatedTempRegs[REG_COUNT] = {false};
reg_t allocTempReg(void) {
	int i;
	for(i = REG_COUNT - 1; i >= 0; --i) {
		if(!allocatedTempRegs[i]) {
			allocatedTempRegs[i] = true;
			//fprintf(stderr, "allocTempReg: allocated \"%s\"\n", registerNames[i]);
			return registerNames[i];
		}
	}
	fprintf(stderr, "error: Register number out of range.\n");
	exit(4);
}
void freeTempReg(reg_t name) {
	int i;
	if(name == NULL)
		return;
	for(i = REG_COUNT - 1; i >= 0; --i) {
		if(strcmp(registerNames[i], name) == 0) {
			allocatedTempRegs[i] = false;
			//fprintf(stderr, "freeTempReg: freed \"%s\"\n", registerNames[i]);
		}
	}
}
_Bool isTempReg(reg_t name) {
	int i;
        if(name == NULL)
                return false;
	for(i = REG_COUNT - 1; i >= 0; --i) {
		if(strcmp(registerNames[i], name) == 0)
			return allocatedTempRegs[i];
	}
	return false;
}
void freeAllRegs(void) {
	int i;
        for(i = REG_COUNT - 1; i >= 0; --i)
		allocatedTempRegs[i] = false;
}
void allocArgRegs(int count) {
	/* FIXME this is mostly in order to know what to save. */
}

