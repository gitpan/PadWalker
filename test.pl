# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..1\n"; }
END {print "not ok 1\n" unless $loaded;}
use PadWalker;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

sub showvars {
  my ($h) = @_;
  while (my ($n,$v) = each %$h) {
    print $n, " => ", $v, "\n";
  }
}

my $outside_var = 12345;

sub foo {
  my $variable = 23;

  {
     my $hmm = 12;
  }
  #my $hmm = 21;

  my $h = PadWalker::peek_my(0);
  showvars($h);

  ${$h->{'$variable'}} = 666;
  print "$variable is now 666\n";
}

sub bar {
  my %x = (1 => 2);
  my $y = 9;

  baz(@_);
  my @z = qw/not yet visible/;
}

sub baz {
  my $baz_var;
  showvars(PadWalker::peek_my(shift));
}

print "-------test 1\n";
foo();
print "-------test 2\n";
bar(1);
print "-------test 3\n";
&{ my @array=qw(fring thrum); sub {bar(2);} };

sub {1};

my $alot_before;
print "-------test 4\n";
showvars(PadWalker::peek_my(0));
print "-------test 5\n";
my $before;
showvars(baz(1));
my $after;

print "-------test 6\n";
showvars(baz(0));

print "-------test 7\n";
sub quux {
  my %quux_var;
  bar(@_);
}

quux(2);
print "-------test 8\n";
quux(3);

print "-------test 9\n";
quux(1);

print "-------test 10\n";
tie my $x, "blah";

my $yyy;
showvars($x);
my $too_late;

package blah;

sub TIESCALAR { my $x=1; bless \$x }
sub FETCH  { return PadWalker::peek_my(1) }
