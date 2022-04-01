#
# Makefile for building the NIF
#
# Makefile targets:
#
# all    build and install the NIF
# clean  clean build products and intermediates
#
# Variables to override:
#
# MIX_APP_PATH  path to the build directory
#
# CC            The C compiler
# CROSSCOMPILE  crosscompiler prefix, if any
# CFLAGS        compiler flags for compiling all C files
# LDFLAGS       linker flags for linking all binaries
#

SRC = c_src/sqlite3_nif.c
HEADERS = c_src/utf8.h

ifeq ($(EXQLITE_USE_SYSTEM),)
	SRC += c_src/sqlite3.c
	HEADERS += c_src/sqlite3.h c_src/sqlite3ext.h
	CFLAGS += -Ic_src
else
	ifneq ($(EXQLITE_SYSTEM_CFLAGS),)
		CFLAGS += $(EXQLITE_SYSTEM_CFLAGS)
	endif

	ifneq ($(EXQLITE_SYSTEM_LDFLAGS),)
		LDFLAGS += $(EXQLITE_SYSTEM_LDFLAGS)
	else
		# best attempt to link the system library
		# if the user didn't supply it in the environment
		LDFLAGS += -lsqlite3
	endif
endif

CFLAGS ?= -O2 -Wall
ifneq ($(DEBUG),)
	CFLAGS += -g
else
	CFLAGS += -DNDEBUG=1
endif
CFLAGS += -I"$(ERTS_INCLUDE_DIR)"

KERNEL_NAME := $(shell uname -s)

PREFIX = $(MIX_APP_PATH)/priv
BUILD  = $(MIX_APP_PATH)/obj
LIB_NAME = $(PREFIX)/sqlite3_nif.so
ARCHIVE_NAME = $(PREFIX)/sqlite3_nif.a

# OBJ = $(BUILD)/sqlite3_nif.o
OBJ = $(SRC:c_src/%.c=$(BUILD)/%.o)

ifneq ($(CROSSCOMPILE),)
	ifeq ($(CROSSCOMPILE), Android)
		CFLAGS += -fPIC -Os -z global
		LDFLAGS += -fPIC -shared
	else
		CFLAGS += -fPIC -fvisibility=hidden
		LDFLAGS += -fPIC -shared
	endif
else
	ifeq ($(KERNEL_NAME), Linux)
		CFLAGS += -fPIC -fvisibility=hidden
		LDFLAGS += -fPIC -shared
	endif
	ifeq ($(KERNEL_NAME), Darwin)
		CFLAGS += -fPIC
		LDFLAGS += -dynamiclib -undefined dynamic_lookup
	endif
	ifeq (MINGW, $(findstring MINGW,$(KERNEL_NAME)))
		CFLAGS += -fPIC
		LDFLAGS += -fPIC -shared
		LIB_NAME = $(PREFIX)/sqlite3_nif.dll
	endif
	ifeq ($(KERNEL_NAME), $(filter $(KERNEL_NAME),OpenBSD FreeBSD NetBSD))
		CFLAGS += -fPIC
		LDFLAGS += -fPIC -shared
	endif
endif

# ########################
# COMPILE TIME DEFINITIONS
# ########################

# For more information about these features being enabled, check out
# --> https://sqlite.org/compile.html
CFLAGS += -DSQLITE_USE_URI -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_THREADSAFE=1 -DSQLITE_DEFAULT_WAL_SYNCHRONOUS=3 -DSQLITE_OMIT_DEPRECATED=1 -DSQLITE_OMIT_SHARED_CACHE=1 -DSQLITE_ENABLE_COLUMN_METADATA=1 -DSQLITE_DISABLE_FTS3 -DSQLITE_ENABLE_LOCKING_STYLE=POSIX -DSQLITE_LIKE_DOESNT_MATCH_BLOBS -DSQLITE_ENABLE_UNLOCK_NOTIFY=1 -DSQLITE_USE_URI -DSQLITE_TEMP_STORE=2 -DUSE_PREAD
CFLAGS += -DSQLITE_DISABLE_LFS -DSQLITE_ENABLE_SESSION -DSQLITE_ENABLE_PREUPDATE_HOOK


ifeq ($(STATIC_ERLANG_NIF),)
all: $(PREFIX) $(BUILD) $(LIB_NAME)
else
all: $(PREFIX) $(BUILD) $(ARCHIVE_NAME)
endif

# $(BUILD)/sqlite3_nif.o: c_src/sqlite3_nif.c
# 	@echo " CC $(notdir $@)"
# 	$(CC) -c $(CFLAGS) -o $@ $<

$(BUILD)/%.o: c_src/%.c
	@echo " CC $(notdir $@)"
	$(CC) -c $(CFLAGS) -o $@ $<

$(LIB_NAME): $(OBJ)
	@echo " LD $(notdir $@) ::: $(LDFLAGS)"
	$(CC) -o $@ $^ $(LDFLAGS)

$(ARCHIVE_NAME): $(OBJ)
	@echo " AR $(notdir $@)"
	$(AR) -rv $@ $^

$(PREFIX) $(BUILD):
	mkdir -p $@

clean:
	$(RM) $(LIB_NAME) $(ARCHIVE_NAME) $(OBJ)

.PHONY: all clean

# Don't echo commands unless the caller exports "V=1"
${V}.SILENT:
