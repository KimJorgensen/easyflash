
###############################################################################
# Common rules
#
# variables used here must be set in the including Makefile

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
	$(cxx) -c $(cxxflags) -o $@ $<

###############################################################################
# This rule can compile <base>/src/*.c to <here>/out/obj/*.o
#
$(objdir)/%.o: $(srcdir)/%.c $(headers) | $(objdir) check-environment
	$(cc) -c $(ccflags) -o $@ $<

###############################################################################
# make clean the simple way
#
.PHONY: clean
clean:
	rm -rf $(outbase)
