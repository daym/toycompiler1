#ifndef __REGALLOC_H
#define __REGALLOC_H
#include "treenode.h"

reg_t allocTempReg(void);
void freeTempReg(reg_t regname);
_Bool isTempReg(reg_t name);
treenode* registerNByIndex(int64_t index);
void freeAllRegs(void);
void allocArgRegs(int count);
#define REG_COUNT 6

#endif /* ndef __REGALLOC_H */

