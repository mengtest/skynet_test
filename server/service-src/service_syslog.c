#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

struct logger {
	FILE * handle;
	char * filename;
	int close;
};

struct logger *
syslog_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->filename = NULL;

	return inst;
}

void
syslog_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst->filename);
	skynet_free(inst);
}

static int
syslog_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source, const void * msg, size_t sz) {
	struct logger * inst = ud;
	switch (type) {
	case PTYPE_SYSTEM:
		if (inst->filename) {
			inst->handle = freopen(inst->filename, "a", inst->handle);
		}
		break;
	case PTYPE_TEXT:
        {
            char timebuf[64];
            struct tm tm;
            time_t now = time(NULL);
            localtime_r(&now, &tm);
            strftime(timebuf, sizeof(timebuf), "%Y/%m/%d-%H:%M:%S", &tm);
            fprintf(inst->handle, "[%s][:%08x] ", timebuf, source);
            fwrite(msg, sz , 1, inst->handle);
            fprintf(inst->handle, "\n");
            fflush(inst->handle);
        }
        break;
	}

	return 0;
}

int
syslog_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		inst->handle = fopen(parm,"w");
		if (inst->handle == NULL) {
			return 1;
		}
		inst->filename = skynet_malloc(strlen(parm)+1);
		strcpy(inst->filename, parm);
		inst->close = 1;
	} else {
		inst->handle = stdout;
	}
	if (inst->handle) {
		skynet_callback(ctx, inst, syslog_cb);
		return 0;
	}
	return 1;
}
