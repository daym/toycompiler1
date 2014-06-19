#include <stdio.h>
#include "asma.h"

static void ref_asma(unsigned char *s, unsigned char *t, unsigned char *u) {
	int i;
	for (i = 0; i < 16; i++)
		u[i] = (s[i]>t[i]) ? s[i] : t[i];
}

int main() {
	unsigned char s[16] = {2,3,4,5,6,7};
	unsigned char t[16] = {7,6,5,4,3,2};
	unsigned char u[16] = {0};
	unsigned char refu[16] = {0};
	ref_asma(s, t, refu);
	asma(s, t, u);
	if(memcmp(u, refu, 16*sizeof(unsigned char)) != 0) {
		int i;
		(void) fprintf(stderr, "test failed!\n");
		for(i = 0; i < 16; ++i) {
			(void) printf("(%u,%u), ", (unsigned) u[i], (unsigned) refu[i]);
		}
		(void) printf("\n");
		fflush(stdout);
		return 1;
	} else
		return 0;
}

