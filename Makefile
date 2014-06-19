
all:
	$(MAKE) -C iburg-bison all
	$(MAKE) -C src all

clean:
	$(MAKE) -C iburg-bison clean
	$(MAKE) -C src clean
