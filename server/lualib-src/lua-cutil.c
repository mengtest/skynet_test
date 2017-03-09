#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include <time.h>

#define CUTIL_BUF_SIZE 3097

typedef struct {
	int buf_sz;
	char* buf;
} cutil_conf_t;

#define uchar(c) ((unsigned char)(c))

#define isdigit(s) (s>=48 && s<=57)
#define isalpha(s) ((s>=65 && s<=90) || (s>=97 && s<=122))


static cutil_conf_t* cutil_fetch_info(lua_State *L)
{
	cutil_conf_t* cfg;
	cfg = lua_touserdata(L, lua_upvalueindex(1));
	if (!cfg)
		luaL_error(L, "Unable to fetch CUTIL cfg");

	return cfg;
}


/* filter special characters, only keep Chinese characters, English letters and numbers.
 * (support for utf8)
 */
static int filter_spec_chars(lua_State *L)
{
	size_t srcl;
	int i;
	int l = 0;
	luaL_Buffer b;
	char *p;
	char* tmp;
	int use_buf = NULL;
	const char* src = luaL_checklstring(L, 1, &srcl);
	cutil_conf_t * cfg = cutil_fetch_info(L);

	if (srcl < cfg->buf_sz) {
		tmp = cfg->buf;
		use_buf = !NULL;
	} else {
		tmp = (char *)malloc(sizeof(char) * srcl);
	}
	if (!tmp) {
		luaL_error(L, "Out of memory");
		return 0;
	}

	for ( i=0; i<srcl; i++) {
		unsigned char s = uchar(src[i]);
		if (s<192) {
			if (isdigit(s) || isalpha(s)) {
				tmp[l++] = s;
			}
		} else if (s<224) {
			i += 1;
		} else if (s<240) {
			if (s>=228 && s<=233 && i<srcl-2) {
				unsigned char s1 = uchar(src[i+1]);
				unsigned char s2 = uchar(src[i+2]);
				int a1=128, a2=191, a3=128, a4=191;
				if (s == 228) {
					a1 = 184;
				} else if (s == 233) {
					a2 = 190;
					a4 = s1!=190? 191: 165;
				}
				if (s1>=a1 && s1<=a2 && s2>=a3 && s2<=a4){
					tmp[l++] = s;
					tmp[l++] = s1;
					tmp[l++] = s2;
				}
			}
			i += 2;
		} else if (s<248) {
			i += 3;
		} else if (s<252) {
			i += 4;
		} else if (s<254) {
			i += 5;
		}
	}

	p = luaL_buffinitsize(L, &b, l);
	memcpy(p, tmp, l * sizeof(char));
	if (!use_buf)
		free(tmp);
	luaL_pushresultsize(&b, l);
	return 1;
}


/* GC, clean up the buf */
static int cutil_gc(lua_State *L)
{
	cutil_conf_t *cfg;
	cfg = lua_touserdata(L, 1);
	if (cfg && cfg->buf)
		free(cfg->buf);

	cfg = NULL;
	return 0;
}

static void cutil_create_config(lua_State *L)
{
	cutil_conf_t *cfg;
	cfg = lua_newuserdata(L, sizeof(*cfg));
	/* Create GC method to clean up buf */
	lua_newtable(L);
	lua_pushcfunction(L, cutil_gc);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);

	cfg->buf = (char *)malloc(sizeof(char) * CUTIL_BUF_SIZE);
	if (!cfg->buf) {
		luaL_error(L, "Unable to create CUTIL cfg");
		return;
	}
	cfg->buf_sz = CUTIL_BUF_SIZE;
}


int luaopen_cutil_core(lua_State *L)
{
	luaL_checkversion(L);
	
	static const luaL_Reg funcs[] = {
		{"filter_spec_chars", filter_spec_chars},
		{NULL, NULL}
	};

	lua_newtable(L);
	cutil_create_config(L);
	luaL_setfuncs(L, funcs, 1);

	return 1;
}
