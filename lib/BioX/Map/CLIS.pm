package BioX::Map::CLIS;
use Modern::Perl;
use IO::All;
use Moo;
use Types::Standard qw/Int Str/;
use MooX::Cmd;
use MooX::Options prefer_commandline => 1;

# VERSION
# ABSTRACT: a mapping toolkit

=head1 DESCRIPTION

=head1 SYNOPOSIS

  use BioX::Map::CLIS;
  BioX::Map::CLIS->new_with_cmd;

=cut

=head2 execute

=cut

sub execute {
  my ($self, $args_ref, $chain_ref) = @_;
  my $pre_message = "\nWarning:\n  this is a apps collection, your can only execute it's sub_command or sub_sub_command. more detail can be obtain by --man paramter\n";
  unless (@$args_ref) {
    say $pre_message;
    $self->options_usage;
  }
}

1;
