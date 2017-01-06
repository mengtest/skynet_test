THIRD_LIB_ROOT ?= ./3rd/

SKYNET_ROOT ?= $(THIRD_LIB_ROOT)skynet
include $(SKYNET_ROOT)/platform.mk

LUA_CLIB_PATH ?= ./server/luaclib
LUA_CSRC_PATH ?= ./server/lualib-src

MYCSERVICE_PATH ?= ./server/cservice
MYCSERVICE_CSRC_PATH ?= ./server/service-src

SHARED := -fPIC --shared
CFLAGS = -g -O2 -Wall

#lua
LUA_CLIB = uuid aoi

#service
MYCSERVICE = test

all : \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)\
  $(foreach v, $(MYCSERVICE), $(MYCSERVICE_PATH)/$(v).so)


$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/uuid.so : $(LUA_CSRC_PATH)/lua-uuid.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/aoi.so : $(LUA_CSRC_PATH)/lua-aoi.c $(LUA_CSRC_PATH)/aoi.c
		$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(MYCSERVICE_PATH) :
	mkdir $(MYCSERVICE_PATH)

$(MYCSERVICE_PATH)/test.so : $(MYCSERVICE_CSRC_PATH)/test.c $(MYCSERVICE_CSRC_PATH)/aoi.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

clean :
	rm $(LUA_CLIB_PATH)/*.so
	rm $(MYCSERVICE_PATH)/*.so

cleanall: clean
