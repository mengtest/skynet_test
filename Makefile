THIRD_LIB_ROOT ?= ./3rd/

SKYNET_ROOT ?= $(THIRD_LIB_ROOT)skynet/
include $(SKYNET_ROOT)platform.mk

LUA_CLIB_PATH ?= ./server/luaclib
LUA_CSRC_PATH ?= ./server/lualib-src

SHARED := -fPIC --shared
CFLAGS = -g -O2 -Wall

# skynet

LUA_CLIB = uuid

all : \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)


$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/uuid.so : $(LUA_CSRC_PATH)/lua-uuid.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@ 

clean :
	rm $(LUA_CLIB_PATH)/*.so

cleanall: clean