THIRD_LIB_ROOT ?= 3rd

LUA_CJSON_ROOT ?= $(THIRD_LIB_ROOT)/lua-cjson
SKYNET_ROOT ?= $(THIRD_LIB_ROOT)/skynet
SKYNET_SRC ?= $(SKYNET_ROOT)/skynet-src
include $(SKYNET_ROOT)/platform.mk

LUA_INC ?= $(SKYNET_ROOT)/3rd/lua

LUA_CLIB_PATH ?= server/luaclib
LUA_CSRC_PATH ?= server/lualib-src

MYCSERVICE_PATH ?= server/cservice
MYCSERVICE_CSRC_PATH ?= server/service-src

SHARED := -fPIC --shared
CFLAGS = -g -O2 -Wall -I$(LUA_INC) -I$(SKYNET_SRC)

#lua
LUA_CLIB = uuid cutil utf8 crab

#service
MYCSERVICE = caoi

all :make3rd createdir \
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)\
	$(foreach v, $(MYCSERVICE), $(MYCSERVICE_PATH)/$(v).so)

make3rd :
	@$(MAKE) -C $(LUA_CJSON_ROOT) --no-print-directory
	@$(MAKE) -C $(SKYNET_ROOT) $(PLAT) --no-print-directory

createdir:
	mkdir -p $(LUA_CLIB_PATH)
	mkdir -p $(MYCSERVICE_PATH)

luaclib : 
	$(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	
cservice : 
	$(foreach v, $(MYCSERVICE), $(MYCSERVICE_PATH)/$(v).so)

$(LUA_CLIB_PATH)/uuid.so : $(LUA_CSRC_PATH)/lua-uuid.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/cutil.so : $(LUA_CSRC_PATH)/lua-cutil.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/utf8.so : $(LUA_CSRC_PATH)/lua-utf8.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(LUA_CLIB_PATH)/crab.so : $(LUA_CSRC_PATH)/lua-crab.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

$(MYCSERVICE_PATH)/caoi.so : $(MYCSERVICE_CSRC_PATH)/service_aoi.c $(MYCSERVICE_CSRC_PATH)/aoi.c
	$(CC) $(CFLAGS) $(SHARED) $^  -o $@

clean :
	rm -f $(LUA_CLIB_PATH)/*.so $(MYCSERVICE_PATH)/*.so

cleanall: clean
	@$(MAKE) -C $(LUA_CJSON_ROOT) clean --no-print-directory
	@$(MAKE) -C $(SKYNET_ROOT) clean --no-print-directory

