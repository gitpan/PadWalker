use strict; use warnings;
use PadWalker 'closed_over';

print "1..16\n";

my $x=2;
my $h = closed_over (my $sub = sub {my $y = $x++});
my @keys = keys %$h;

print (@keys == 1 ? "ok 1\n" : "not ok 1\n");
print (${$h->{'$x'}} eq 2 ? "ok 2\n" : "not ok 2\n");

print ($sub->() == 2 ? "ok 3\n" : "not ok 3\n");
print ($sub->() == 3 ? "ok 4\n" : "not ok 4\n");

${$h->{"\$x"}} = 7;

print ($sub->() == 7 ? "ok 5\n" : "not ok 5\n");
print ($sub->() == 8 ? "ok 6\n" : "not ok 6\n");

{my $x = "hello";

sub foo {
  ++$x
}}

$h = closed_over(\&foo);
@keys = keys %$h;

print (@keys == 1 ? "ok 7\n" : "not ok 7\n");
print (${$h->{'$x'}} eq "hello" ? "ok 8\n" : "not ok 8 # $h->{'$x'} -> ${$h->{'$x'}}\n");

foo();
print (${$h->{'$x'}} eq "hellp" ? "ok 9\n" : "not ok 9 # $h->{'$x'} -> ${$h->{'$x'}}\n");

${$h->{'$x'}} = "phooey";
foo();
print (${$h->{'$x'}} eq "phooez" ? "ok 10\n" : "not ok 10 # $h->{'$x'} -> ${$h->{'$x'}}\n");

sub bar{
  bar(2) if !@_;
  my $m = 13 - (@_ && $_[0]);
  my $n = $m+1;

  $h = closed_over(\&bar);
  @keys = keys %$h;
  print (@keys == 2 ? "ok $m\n" : "not ok $m\n");
  print ($h->{'$h'} = \$h ? "ok $n\n" : "not ok $n\n");
  
  # Break the circular data structure:
  delete $h->{'$h'};
}
bar();

our $blah = 9;
my $blah = sub {$blah};
my ($vars, $indices) = closed_over($blah);
print (keys %$vars == 0 ? "ok 15\n" : "not ok 15\n");
print (keys %$indices == 0 ? "ok 16\n" : "not ok 16\n");
