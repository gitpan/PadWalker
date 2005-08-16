use ExtUtils::MakeMaker;

use strict;

my $DEBUGGING = '';
if (@ARGV) {
  warn "Configuring a debugging build of PadWalker\n";
  $DEBUGGING = '-DPADWALKER_DEBUGGING';
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
