use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

my $DEBUGGING = '';
if (@ARGV) {
  warn "Configuring a debugging build of PadWalker\n";
  $DEBUGGING = '-DPADWALKER_DEBUGGING';
}

WriteMakefile(
    'NAME'	=> 'PadWalker',
    'VERSION_FROM' => 'PadWalker.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> $DEBUGGING,
    'INC'	=> '',     # e.g., '-I/usr/include/other' 
);
