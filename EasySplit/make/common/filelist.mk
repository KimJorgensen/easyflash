
outbase       := out
outdir        := $(outbase)/EasySplit
objdir        := $(outbase)/obj
srcdir        := ../../src

###############################################################################
# This is the list of source files to be compiled
#
src := 
src += EasySplitApp.cpp
src += EasySplitMainFrame.cpp
src += WorkerThread.cpp
src += match.c
src += optimal.c
src += search.c
src += radix.c
src += progress.c
src += output.c
src += chunkpool.c
src += membuf.c
src += membuf_io.c
src += exo_helper.c
src += exodec.c
src += getflag.c
src += exo_util.c
src += crc16.c
src += easysplit.png

###############################################################################
# This is a list of resource file to be built/copied
#
res := easysplit.png

###############################################################################
# Transform all names foo.cpp|c in $src to out/obj/foo.o
#
src_cpp := $(filter %.cpp,$(src))
obj     := $(addprefix $(objdir)/, $(src_cpp:.cpp=.o))
src_c   := $(filter %.c,$(src))
obj     += $(addprefix $(objdir)/, $(src_c:.c=.o))
src_png := $(filter %.png,$(src))
xpm     := $(addprefix $(objdir)/, $(src_png:.png=.xpm))

###############################################################################
# Transform all names in $res to out/MultiColor/res/*
# 
outres := $(addprefix $(outdir)/res/, $(res))

###############################################################################
# Poor men's dependencies: Let all files depend from all header files
# 
headers := $(wildcard $(srcdir)/*.h) $(xpm)
