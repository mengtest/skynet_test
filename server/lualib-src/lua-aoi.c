#include "aoi.h"
#include <lua.h>
#include <lauxlib.h>
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

lua_State *_L = NULL;
static void
callbackmessage(void *ud, uint32_t watcher, uint32_t marker) {
	lua_getglobal(_L,"aoicallback");
	lua_pushinteger(_L,watcher);
	lua_pushinteger(_L,marker);
	lua_pcall(_L,2,0,0);
}

struct alloc_cookie cookie = { 0,0,0 };
struct aoi_space * space = NULL;

static int
lupdate (lua_State *L) {
	uint32_t id = luaL_checkinteger(L, 1);
	const char *mode = luaL_checkstring(L, 2);
	float pos[3] = {0};
	pos[0] = luaL_checknumber(L, 3);
	pos[1] = luaL_checknumber(L, 4);
	pos[2] = luaL_checknumber(L, 5);

	aoi_update(space, id, mode, pos);
	return 1;
}

static int
lmessage (lua_State *L) {
	aoi_message(space, callbackmessage, NULL);
	return 1;
}

static int
linit (lua_State *L) {
	_L = L;
  space = aoi_create(my_alloc , &cookie);
	return 1;
}

static int
lrelease (lua_State *L) {
	aoi_release(space);
	return 1;
}

static int
lmeminfo (lua_State *L) {
	lua_pushinteger (L, cookie.count);
	lua_pushinteger (L, cookie.max);
	lua_pushinteger (L, cookie.current);
	return 3;
}

int
luaopen_aoi_core (lua_State *L) {
	luaL_checkversion (L);
	luaL_Reg l[] = {
		{ "update", lupdate },
		{ "message", lmessage },
  	{ "init", linit },
    { "release", lrelease },
		{ "meminfo", lmeminfo },
		{ NULL, NULL },
	};
	luaL_newlib (L,l);
	return 1;
}
