.SUFFIXES: .exe .pl .pm


all: esmodpp.exe escat.exe

.pl.exe:
	pp -z 0 -o $@ $<

esmodpp.pl: ESModPP.pm
	touch esmodpp.pl

ESModPP.pm: ESModPP/Parser.pm
	touch ESModPP.pm

