uname_s := $(shell sh -c 'uname -s 2>/dev/null || echo unknown')

distroot  ?= $(CURDIR)/priv
buildroot ?= _build/dev

bin_elixir    ?= elixir
bin_pkgconfig ?= pkg-config
bin_install   ?= install
ifeq ($(uname_s),Darwin)
bin_libtool ?= glibtool
else
bin_libtool ?= libtool
endif

erl_cflags      := -I$(shell $(bin_elixir) $(CURDIR)/ext/bin/erlang-include-dirs.exs)
liblink_rpath   := $(shell $(CURDIR)/ext/bin/rpath $(liblink_ldflags))
liblink_ldlibs  := $(shell $(bin_pkgconfig) --libs-only-l libczmq)
liblink_cflags  := -pthread -Isrc -pedantic $(erl_cflags) $(shell $(bin_pkgconfig) --cflags libczmq)
liblink_ldflags := -rpath $(liblink_rpath) $(shell $(bin_pkgconfig) --libs-only-L libczmq)

srcfiles = $(wildcard src/*.c)
objfiles = $(addprefix $(buildroot)/, $(addsuffix .lo, $(basename $(srcfiles))))

libname = liblink
libfile = $(buildroot)/$(libname).la

compile: $(libfile)

clean:
	$(bin_libtool) --mode=clean rm -f $(libfile)
	$(bin_libtool) --mode=clean rm -f $(objfiles)

install: $(distroot)/lib/$(libname).la

$(distroot)/lib/$(libname).la: $(libfile)
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --mode=install $(bin_install) $(<) $(@)
	if [ ! -e $(@D)/$(libname).so ]; \
	then \
	  if [ -e $(@D)/$(libname).dylib ]; \
	  then ln -s $(libname).dylib $(@D)/$(libname).so; fi; \
	fi

$(buildroot)/%.lo: %.c
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --tag=CC --mode=compile $(CC) $(CFLAGS) $(liblink_cflags) -c $(<) -o $(@)

$(libfile): $(objfiles)
	test -d $(@D) || mkdir -p $(@D)
	$(bin_libtool) --tag=CC --mode=link $(CC) $(LD_FLAGS) $(liblink_ldflags) -o $(@) $(^) $(LD_LIBS) $(liblink_ldlibs)
