package PadWalker;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);

require DynaLoader;

require 5.006;

@ISA = qw(Exporter DynaLoader);
@EXPORT_OK = qw(peek_my peek_sub);

$VERSION = '0.06';

bootstrap PadWalker $VERSION;

sub peek_my;


1;
__END__

=head1 NAME

PadWalker - walk pads

=head1 SYNOPSIS

  use PadWalker qw(peek_my peek_sub);
  ...

=head1 DESCRIPTION

PadWalker is a module which allows you to inspect (and even change!)
lexical variables in any subroutine which called you. It will only
show those variables which are in scope at the point of the call.

The C<peek_my> routine takes one parameter, the number of call levels
to go back. (It works the same way as caller() does.) It returns a
reference to a hash which associates each variable name with a reference
to its value. The variable names include the prefix, so $x is actually '$x'.

For example:
  my $x = 12;
  my $h = peek_my (0);
  ${$h->{'$x'}}++;

  print $x;  # prints 13

Or a more complex example:

  sub increment_my_x {
    my $h = peek_my (1);
    ${$h->{'$x'}}++;
  }

  my $x=5;
  increment_my_x;
  print $x;  # prints 6

The C<peek_sub> routine takes a coderef as its argument, and returns a hash
of the lexical variables used in that sub.

=head1 AUTHOR

Robin Houston <robin@kitsite.com>

With contributions from Richard Soberberg.

=head1 SEE ALSO

perl(1).

=head1 COPYRIGHT

Copyright (c) 2000-2002, Robin Houston. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the same terms as Perl itself.

=cut
