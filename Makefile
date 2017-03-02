THIRD_LIB_ROOT ?= ./3rd/

SKYNET_ROOT ?= $(THIRD_LIB_ROOT)skynet
SKYNET_SRC ?= $(SKYNET_ROOT)/skynet-src
include $(SKYNET_ROOT)/platform.mk

LUA_CLIB_PATH ?= ./server/luaclib
LUA_CSRC_PATH ?= ./server/lualib-src

MYCSERVICE_PATH ?= ./server/cservice
MYCSERVICE_CSRC_PATH ?= ./server/service-src

SHARED := -fPIC --shared
CFLAGS = -g -O2 -Wall

#lua
LUA_CLIB = uuid cutil utf8 crab

#service
MYCSERVICE = caoi

all : \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)\
  $(foreach v, $(MYCSERVICE), $(MYCSERVICE_PATH)/$(v).so)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(MYCSERVICE_PATH) :
	mkdir $(MYCSERVICE_PATH)

$(LUA_CLIB_PATH)/uuid.so : $(LUA_CSRC_PATH)/lua-uuid.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/cutil.so : $(LUA_CSRC_PATH)/lua-cutil.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/utf8.so : $(LUA_CSRC_PATH)/lua-utf8.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/crab.so : $(LUA_CSRC_PATH)/lua-crab.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

#$(LUA_CLIB_PATH)/aoi.so : $(LUA_CSRC_PATH)/lua-aoi.c $(LUA_CSRC_PATH)/aoi.c
#	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(MYCSERVICE_PATH)/caoi.so : $(MYCSERVICE_CSRC_PATH)/service_aoi.c $(MYCSERVICE_CSRC_PATH)/aoi.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@ -I$(SKYNET_SRC)

clean :
	rm -f $(LUA_CLIB_PATH)/*.so $(MYCSERVICE_PATH)/*.so

cleanall: clean
