#include "aoi.h"
#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int addr = 0;

struct alloc_cookie {
	int count;
	int max;
	int current;
};

struct alloc_cookie cookie = { 0,0,0 };

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

static void
callbackmessage(void *ud, uint32_t watcher, uint32_t marker) {
	struct skynet_context * ctx = ud;
	size_t sz = sizeof(uint32_t) * 2 + 2 + 1 + sizeof("aoicallback");
	char * msg = skynet_malloc(sz);
	memset(msg,0,sz);
	sprintf(msg,"aoicallback %u %u ",watcher,marker);
	skynet_send(ctx,0,addr,PTYPE_TEXT|PTYPE_TAG_DONTCOPY,0,(void *)msg,sz);
}

static void
_parm(char *msg, int sz, int command_sz) {
	while (command_sz < sz) {
		if (msg[command_sz] != ' ')
			break;
		++command_sz;
	}
	int i;
	for (i=command_sz;i<sz;i++) {
		msg[i-command_sz] = msg[i];
	}
	msg[i-command_sz] = '\0';
}

static void
_ctrl(struct skynet_context * ctx, struct aoi_space * space, const void * msg, int sz) {
	char tmp[sz+1];
	memcpy(tmp, msg, sz);
	tmp[sz] = '\0';
	char * command = tmp;
	int i;
	if (sz == 0)
		return;
	for (i=0;i<sz;i++) {
		if (command[i]==' ') {
			break;
		}
	}
	if (memcmp(command,"update",i)==0) {
		_parm(tmp, sz, i);
		char * text = tmp;
		char * idstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		int id = strtol(idstr , NULL, 10);
		char * mode = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		float pos[3] = {0};
		char * posstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		pos[0] = strtof(posstr , NULL);
		posstr = strsep(&text, " ");
		if (text == NULL) {
			return;
		}
		pos[1] = strtof(posstr , NULL);
		posstr = strsep(&text, " ");
		pos[2] = strtof(posstr , NULL);
		//printf("id:%d,mode:%s,pos:%f-%f-%f\n",id,mode,pos[0],pos[1],pos[2]);
		aoi_update(space, id, mode, pos);
		aoi_message(space, callbackmessage, ctx);
		return;
	}
	skynet_error(ctx, "[aoi] Unkown command : %s", command);
}

struct aoi_space *
caoi_create(void) {
	struct aoi_space * space = aoi_create(my_alloc , &cookie);
	return space;
}

void
caoi_release(struct aoi_space * space) {
	aoi_release(space);
}

static int
caoi_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct aoi_space * space = ud;
	switch (type) {
	case PTYPE_TEXT:
		_ctrl(context , space , msg , (int)sz);
		break;
	}

	return 0;
}

int
caoi_init(struct aoi_space * space, struct skynet_context *ctx, const char * parm) {
	int n = sscanf(parm, "%d",&addr);
	if (n<1){
		skynet_error(ctx, "Invalid gate parm %s",parm);
		return 1;
	}
	skynet_callback(ctx, space, caoi_cb);
	return 0;
}
