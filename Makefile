PACKAGES = lwt,lwt.unix,lwt.extra,extlib,unix
FILES = memcache.ml

LIBNAME = memcache
VERSION := $(shell head -n 1 VERSION)
CAMLC   = ocamlfind ocamlc   -thread -g $(LIB)
CAMLOPT = ocamlfind ocamlopt -thread -g $(LIB)
CAMLDOC = ocamlfind ocamldoc -thread $(LIB)
CAMLDEP = ocamlfind ocamldep
LIB = -package $(PACKAGES)
PP =

OBJS    = $(FILES:.ml=.cmo)
OPTOBJS = $(FILES:.ml=.cmx)

CMA  = $(LIBNAME).cma
CMXA = $(LIBNAME).cmxa
CMXS = $(LIBNAME).cmxs

all: byte native shared

tests: byte native test.ml
	$(CAMLC) $(CMA) test.ml -linkpkg -o test
	$(CAMLOPT) $(CMXA) test.ml -linkpkg -o test.opt

benchmarks: byte native benchmark.ml
	$(CAMLC) $(CMA) benchmark.ml -linkpkg -o benchmark
	$(CAMLOPT) $(CMXA) benchmark.ml -linkpkg -o benchmark.opt

META: META.in VERSION
	cp $< $@
	sed "s/_NAME_/$(LIBNAME)/" -i $@
	sed "s/_VERSION_/$(VERSION)/" -i $@
	sed "s/_REQUIRES_/$(PACKAGES)/" -i $@
	sed "s/_BYTE_/$(CMA)/" -i $@
	sed "s/_NATIVE_/$(CMXA)/" -i $@
	sed "s/_SHARED_/$(CMXS)/" -i $@

byte: depend $(CMA) META

$(CMA): $(OBJS)
	$(CAMLC) -a -o $(CMA) $(OBJS)

native: depend $(CMXA) META

$(CMXA): $(OPTOBJS)
	$(CAMLOPT) -a -o $(CMXA) $(OPTOBJS)

shared: depend $(CMXS) META

$(CMXS): $(OPTOBJS)
	$(CAMLOPT) -shared -o $(CMXS) $(OPTOBJS)

install:
	ocamlfind install $(LIBNAME) META $(CMA) $(CMXA) $(CMXS) $(wildcard *.a)

uninstall:
	ocamlfind remove $(LIBNAME)

.SUFFIXES:
.SUFFIXES: .ml .mli .cmo .cmi .cmx

.PHONY: doc

.ml.cmo:
	$(CAMLC) $(PP) -c $<
.mli.cmi:
	$(CAMLC) -c $<
.ml.cmx:
	$(CAMLOPT) $(PP) -c $<

doc:
	-mkdir -p doc
	$(CAMLDOC) -d doc -html *.mli

clean:
	-rm -f *.cm[ioxa] *.cmx[as] *.o *.a *~
	-rm -f .depend
	-rm -rf doc
	-rm -f META test test.opt
	-rm -f benchmark benchmark.opt

depend: .depend

.depend: $(FILES)
	$(CAMLDEP) $(PP) $(LIB) $(FILES:.ml=.mli) $(FILES) > .depend

FORCE:

-include .depend
