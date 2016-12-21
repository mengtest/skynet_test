#include "aoi.c"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct alloc_cookie {
	int count;
	int max;
	int current;
};

static void *
my_alloc(void * ud, void *ptr, size_t sz) {
	struct alloc_cookie * cookie = ud;
	if (ptr == NULL) {
		void *p = malloc(sz);
		++ cookie->count;
		cookie->current += sz;
		if (cookie->max < cookie->current) {
			cookie->max = cookie->current;
		}
//		printf("%p + %u\n",p, sz);
		return p;
	}
	-- cookie->count;
	cookie->current -= sz;
//	printf("%p - %u \n",ptr, sz);
	free(ptr);
	return NULL;
}

struct OBJECT {
	float pos[3];
	float v[3];
	char mode[4];
};

static struct OBJECT OBJ[4];

static void
init_obj(uint32_t id, float x, float y, float vx, float vy, const char *mode) {
	OBJ[id].pos[0] =x;
	OBJ[id].pos[1] =y;
	OBJ[id].pos[2] =0;

	OBJ[id].v[0] =vx;
	OBJ[id].v[1] =vy;
	OBJ[id].v[2] =0;

	strcpy(OBJ[id].mode, mode);
}

static void
update_obj(struct aoi_space *space, uint32_t id) {
	int i;
	for (i=0;i<3;i++) {
		OBJ[id].pos[i] += OBJ[id].v[i];
		if (OBJ[id].pos[i] < 0) {
			OBJ[id].pos[i]+=100.0f;
		} else if (OBJ[id].pos[i] > 100.0f) {
			OBJ[id].pos[i]-=100.0f;
		}
	}
	aoi_update(space, id, OBJ[id].mode, OBJ[id].pos);
}

static void
message(void *ud, uint32_t watcher, uint32_t marker) {
	printf("%u (%f,%f) => %u (%f,%f)\n",
		watcher, OBJ[watcher].pos[0], OBJ[watcher].pos[1],
		marker, OBJ[marker].pos[0], OBJ[marker].pos[1]
	);
}

static void
test(struct aoi_space * space) {
	init_obj(0,40,0,0,1,"w");
	init_obj(1,42,100,0,-1,"wm");
	init_obj(2,0,40,1,0,"w");
	init_obj(3,100,45,-1,0,"wm");

	int i,j;
	for (i=0;i<100;i++) {
		if (i<50) {
			for (j=0;j<4;j++) {
				update_obj(space,j);
			}
		} else if (i==50) {
			aoi_update(space, 3, "d", OBJ[3].pos);
		} else {
			for (j=0;j<3;j++) {
				update_obj(space,j);
			}
		}
		aoi_message(space, message, NULL);
	}
}

struct aoi_space *
test_create(void) {
	printf("test_create\n");
	struct alloc_cookie cookie = { 0,0,0 };
	struct aoi_space * space = aoi_create(my_alloc , &cookie);
	return space;
}

void
test_release(struct aoi_space * space) {
	printf("test_release\n");
	aoi_release(space);
}

int
test_init(struct aoi_space * space) {
	printf("test_init\n");
	test(space);
	return 0;
}