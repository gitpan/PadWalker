my $blah;
do "test.pl";
die $@ if $@;

print "--------------------\n";
showvars(PadWalker::peek_my(0));

