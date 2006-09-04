all: esmodpp escat

esmodpp: esmodpp.pl ESModPP.pm ESModPP/Parser.pm
	pp -x -z 0 -o esmodpp.exe esmodpp.pl

escat: esmodpp escat.pl ESModPP/ESCat.pm
	pp -x -z 0 -o escat.exe escat.pl
