use ExtUtils::MakeMaker;

use strict;

# Remember (like I didn't) that WriteMakefile looks at @ARGV,
# so an alternative way to configure a debugging build is:
# perl Makefile.PL DEFINE=-DPADWALKER_DEBUGGING.
my $DEBUGGING = '';
if (@ARGV && $ARGV[0] eq '-d') {
  warn "Configuring a debugging build of PadWalker\n";
  print STDERR <<END;
************************************************************************
* WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING! *
************************************************************************
You are building PadWalker in debugging mode, which causes it to
print a lot of gnomic information about its internal operation.
The test suite will fail, because this information will confuse
the test harness. You almost certainly do *not* want to do this
unless you're the author of PadWalker (or perhaps just irrepressibly
curious about its internal operation).

END

  $DEBUGGING = '-DPADWALKER_DEBUGGING';
  shift;
}

require 5.00502;
if ($^V < 5.008) {
  print STDERR <<END;
************************************************************************
* WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING! *
************************************************************************
Padwalker does *not* work properly with versions of Perl prior to 5.8.
You can use it if you like, but some tests *will* fail. To be precise,
these three tests are expected to fail:

Failed Test Stat Wstat Total Fail  Failed  List of Failed
-------------------------------------------------------------------------------
t/foo.t                    3    2  66.67%  1 3
t/test.t                  15    1   6.67%  9

If any of the *others* fail, please regard that as a bug and report
it in the usual way.

This is not a regression. The failing tests detect bugs that were
present in all versions of PadWalker prior to 0.11. Unfortunately
the fix for these bugs relies on a feature that was introduced in
Perl 5.8.

If you're upgrading PadWalker, and you absolutely *have* to use an
obsolete version of Perl, then go ahead and upgrade. You won't be
any worse off than before. In fact you'll be slightly better off,
because the old version would erroneously detect 'our' variables
and this new one doesn't.

END
  my $answer;
  for ($answer = ''; $answer ne 'yes' && $answer ne 'no';) {
    print "Do you want to continue? [yes/no]\n";
    $answer = <>;
    chomp $answer;
  }
  exit 1 if ($answer eq 'no');
}

WriteMakefile(
    'NAME'	=> 'PadWalker',
    'VERSION_FROM' => 'PadWalker.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> $DEBUGGING,
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
