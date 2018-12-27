#include "skynet.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>
#include <stdbool.h>

#define ONE_MB	(1024 * 1024)
#define DEFAULT_ROLL_SIZE (1024 * ONE_MB)  // 单个文件大小大于xGB的时候新建log文件
#define FILE_TIME (3600) // 每小时生成新的log文件

struct logger {
	FILE * handle;
	char * filename;
	char * pathname;
	int close;
	int filesize;
	int index;
	time_t filetime;
};

struct logger *
syslog_create(void) {
	struct logger * inst = skynet_malloc(sizeof(*inst));
	inst->handle = NULL;
	inst->close = 0;
	inst->filesize = 0;
	inst->index = 0;
	inst->filetime = 0;
	inst->filename = NULL;
	inst->pathname = NULL;

	return inst;
}

void
syslog_release(struct logger * inst) {
	if (inst->close) {
		fclose(inst->handle);
	}
	skynet_free(inst->filename);
	skynet_free(inst->pathname);
	skynet_free(inst);
}

void
genfilename(struct logger * inst, time_t now) {
	char filename[64];
	struct tm tm;
	localtime_r(&now, &tm);
	sprintf(filename, "%d-%d-%d:%d_%d.log", tm.tm_year + 1900, tm.tm_mon, tm.tm_mday, tm.tm_hour, inst->index);

	if(inst->filename != NULL)
		skynet_free(inst->filename);
	inst->filename = skynet_malloc(strlen(inst->pathname)+strlen(filename)+1);
	sprintf(inst->filename, "%s/%s", inst->pathname, filename);
}

bool
trycreatenewlogfile(struct logger * inst, time_t now){
	if(inst->filetime != now/FILE_TIME)
	{
		inst->filetime = now/FILE_TIME;
		inst->index = 0;
		inst->filesize = 0;
		genfilename(inst, now);
		return true;
	}
	else if(inst->filesize >= DEFAULT_ROLL_SIZE)
	{
		inst->index += 1;
		inst->filesize = 0;
		genfilename(inst, now);
		return true;
	}
	return false;
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
            struct tm tm;
            time_t now = time(NULL);
			if(trycreatenewlogfile(inst,now))
			{
				fclose(inst->handle);
				inst->handle = fopen(inst->filename,"w");
				if (inst->handle == NULL) {
					skynet_error(context, "create log file fail![%s]\n", inst->filename);
				}
			}
            localtime_r(&now, &tm);
            fprintf(inst->handle, "[%d/%d/%d-%d:%d:%d][:%08x] ", tm.tm_year + 1900, tm.tm_mon, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec, source);
            fwrite(msg, sz , 1, inst->handle);
            fprintf(inst->handle, "\n");
            inst->filesize += fflush(inst->handle);
        }
        break;
	}

	return 0;
}

int
syslog_init(struct logger * inst, struct skynet_context *ctx, const char * parm) {
	if (parm) {
		inst->pathname = skynet_malloc(strlen(parm)+1);
		strcpy(inst->pathname, parm);
		trycreatenewlogfile(inst, time(NULL));
		inst->handle = fopen(inst->filename,"w");
		if (inst->handle == NULL) {
			skynet_free(inst->filename);
			skynet_free(inst->pathname);
			return 1;
		}
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
