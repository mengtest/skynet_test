THIRD_LIB_ROOT ?= 3rd
LUA_CJSON_ROOT ?= $(THIRD_LIB_ROOT)/lua-cjson
SKYNET_ROOT ?= $(THIRD_LIB_ROOT)/skynet
include $(SKYNET_ROOT)/platform.mk
SKYNET_SRC ?= $(SKYNET_ROOT)/skynet-src
LUA_INC ?= $(SKYNET_ROOT)/3rd/lua

SHARED += -fPIC --shared
CFLAGS += -g -O2 -Wall -I$(LUA_INC) -I$(SKYNET_SRC)

#lua
LUACLIB_PATH ?= server/luaclib
LUACLIB_SRC_PATH ?= server/lualib-src

#获取$(LUACLIB_SRC_PATH)目录下所有文件名
LUA_CLIB_NAME = $(patsubst lua-%.c, %, $(notdir $(wildcard $(LUACLIB_SRC_PATH)/*.c)))
#获取$(LUACLIB_SRC_PATH)目录下所有文件名
LUACLIB_OBJ = $(foreach v, $(LUA_CLIB_NAME), $(LUACLIB_PATH)/$(v).so)

#service
CSERVICE_PATH ?= server/cservice
CSERVICE_CSRC_PATH ?= server/service-src

CSERVICE_NAME = caoi syslog
CSERVICE_OBJ = $(foreach v, $(CSERVICE_NAME), $(CSERVICE_PATH)/$(v).so)

VPATH += $(LUACLIB_SRC_PATH)
VPATH += $(CSERVICE_CSRC_PATH)

linux macosx freebsd : make3rd createdir $(LUACLIB_OBJ) $(CSERVICE_OBJ)

make3rd :
	@$(MAKE) $(PLAT) -C $(SKYNET_ROOT) --no-print-directory
	@$(MAKE) -C $(LUA_CJSON_ROOT) --no-print-directory

createdir:
	@mkdir -p $(LUACLIB_PATH)
	@mkdir -p $(CSERVICE_PATH)

$(LUACLIB_OBJ) : $(LUACLIB_PATH)/%.so : lua-%.c 
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/caoi.so : service_aoi.c aoi.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(CSERVICE_PATH)/%.so : service_%.c
	@echo "	$@"
	@$(CC) $(CFLAGS) $(SHARED) $^ -o $@

clean :
	$(RM) $(LUACLIB_OBJ) $(CSERVICE_OBJ)

cleanall: clean
	@$(MAKE) -C $(LUA_CJSON_ROOT) clean --no-print-directory
	@$(MAKE) -C $(SKYNET_ROOT) clean --no-print-directory

.PHONY : linux macosx freebsd make3rd createdir clean cleanall