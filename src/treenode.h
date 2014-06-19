#ifndef __TREENODE_H
#define __TREENODE_H
#include <stdint.h>

#define ADD 1
#define REG 2
#define NUM 3
#define ASSIGN 4
#define ADDASSIGN 5
#define NEQ 6
#define MUL 7
#define OR 8
#define NOT 9
#define SUB 10
#define DEREF 11 /* rax = (rax) */
#define NEG 12
#define GT 13
#define WDEREF 14
#define THEN_ELSE 15
#define SEQUENCE 16
#define RET 17
#define SENTINEL 18
#define TEST_BOOL 19
#define CALL 20
#define LABEL 21
#define CALLARGS 22
#define CALLCFG 23

#define RAX "%rax"
#define REG_EQ(a,b) (((a) == NULL && (b) == NULL) || ((a) != NULL && (b) != NULL && strcmp((a), (b)) == 0)) 

/* %rdi, %rsi, %rdx, %rcx, %r8 and %r9 */

#ifdef USE_IBURG
#ifndef BURM
typedef struct burm_state *STATEPTR_TYPE;
#endif
#else
#define STATEPTR_TYPE int
#endif

typedef const char* reg_t;

typedef struct s_node {
	int             op/*operator_*/;
	struct s_node*  kids[2];
	STATEPTR_TYPE   state;
        /* user defined data fields follow here */
	reg_t          regname;
	uint64_t        value;
	const char*     label;
} treenode;

typedef treenode *treenodep;

#define NODEPTR_TYPE	treenodep
#define OP_LABEL(p)	((p)->op)
#define LEFT_CHILD(p)	((p)->kids[0])
#define RIGHT_CHILD(p)	((p)->kids[1])
#define STATE_LABEL(p)	((p)->state)
#define PANIC		printf

treenode* operationN(int op/*erator*/, treenode* c0, treenode* c1, treenode* c2, const char* regname, uint64_t value, const char* label);
treenode* soperationN(int op/*erator*/, treenode* c0, treenode* c1);
treenode* iteN(treenode* c0, treenode* c1, treenode* c2);
treenode* registerN(const char* regname);
treenode* labelN(const char* label);
treenode* sentinelN(void);
treenode* immediateN(uint64_t value);

#endif
