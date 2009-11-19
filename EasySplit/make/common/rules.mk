
###############################################################################
# Common rules
#
# variables used here must be set in the including Makefile

INCLUDE += -I$(objdir)

# don't delete intermediate files
.SECONDARY:

###############################################################################
# This rule can copy files from <base>/res/* to <outdir>/res/*
#
$(outdir)/res/%: $(srcdir)/../res/%
	mkdir -p $(dir $@)
	cp $^ $@

###############################################################################
# This rule can create the directories we need
#
$(outdir) $(objdir):
	mkdir -p $@

###############################################################################
# This rule can compile <base>/src/*.cpp to <here>/out/obj/*.o
#
$(objdir)/%.o: $(srcdir)/%.cpp $(headers) | $(objdir) check-environment
	$(cxx) -c $(cxxflags) $(INCLUDE) -o $@ $<

###############################################################################
# This rule can compile <base>/src/*.c to <here>/out/obj/*.o
#
$(objdir)/%.o: $(srcdir)/%.c $(headers) | $(objdir) check-environment
	$(cc) -c $(ccflags) $(INCLUDE) -o $@ $<

###############################################################################
# This rule can compile <base>/res/*.png to <here>/out/obj/*.xpm
#
$(objdir)/%.xpm: $(srcdir)/../res/%.png | $(objdir) check-environment
	convert $< $@.tmp.xpm
	cat $@.tmp.xpm | sed "s/static char/static const char/;s/_tmp//" > $@

###############################################################################
# make clean the simple way
#
.PHONY: clean
clean:
	rm -rf $(outbase)
