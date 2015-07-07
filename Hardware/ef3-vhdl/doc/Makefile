
pdfs := kernal-cartridge.pdf

# images to be converted
images := $(wildcard src/*.svg)
images += $(wildcard src/*.pdf)
images += $(wildcard src/*.ps)
images += $(wildcard src/*.png)
images := $(images:.ps=.pdf)
images := $(images:.svg=.pdf)
images := $(patsubst src/%,obj/%,$(images))

latex_flags := -output-directory obj
#latex_flags += -interaction=batchmode
latex_flags += -halt-on-error

###############################################################################
.PHONY: all
all: $(pdfs)

###############################################################################
%.pdf: src/%.tex $(images) always
	pdflatex $(latex_flags) $<
	pdflatex $(latex_flags) $<

###############################################################################
.PHONY: always
always:

###############################################################################
obj/%.v15.pdf: src/%.svg obj/images
	inkscape $< --export-pdf=$@ 

###############################################################################
obj/%.pdf: src/%.ps obj/images
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dEPSCrop \
		-dNOPAUSE -dQUIET -dBATCH -sOutputFile=$@ $<

###############################################################################
obj/%.png: src/%.png obj/images
	cp $< $@ 

###############################################################################
# Convert version 1.5 PDF files to version 1.4 (cairosvg/inkscape cmd line
# creates 1.5, latex wants 1.4) 
#
%.pdf: %.v15.pdf
	gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 \
		-dNOPAUSE -dQUIET -dBATCH -sOutputFile=$@ $<

###############################################################################
# create directories 
#
obj:
	mkdir -p $@

obj/images:
	mkdir -p $@

###############################################################################
.PHONY: clean
clean:
	rm -f src/*.toc
	rm -f src/*.dvi
	rm -f src/*.aux
	rm -f src/*.log
	rm -f src/*.out
	rm -f *~
	rm -rf obj
