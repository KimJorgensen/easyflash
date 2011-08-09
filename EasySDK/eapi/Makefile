
EAPI := out/eapi-am29f040-13 out/eapi-m29w160t-03 out/eapi-mx29640b-01

.PHONY: all
all: test.prg $(EAPI)

###############################################################################
out/eapi-am29f040-13: eapi-am29f040.s out
	acme -o $@ $<

out/eapi-m29w160t-03: eapi-m29w160t.s out
	acme -o $@ $<

out/eapi-mx29640b-01: eapi-mx29640b.s out
	acme -o $@ $<

###############################################################################
out:
	mkdir -p $@


.PHONY: clean
clean:
	rm -f $(EAPI)
	-rmdir out
