package BioX::Map::CLIS::Cmd::Map;
use Modern::Perl;
use IO::All;
use Carp "confess";
use Moo;
use MooX::Options prefer_commandline => 1, with_config_from_file => 1;
use MooX::Cmd;
use BioX::Map;
use Types::Standard qw(Int Str Bool Enum);

# VERSION:
# ABSTRACT: a wrapper for mapping software

=head1 DESCRIPTION

  used to mapped a or more sample.

=head1 SYNOPSIS

  use BioX::Map::CLIS::Cmd::Map;
  BioX::Map::CLIS::Cmd::Map->new_with_cmd;

=head1 Attribute

=cut

around _build_config_identifier => sub { 'berry' };
around _build_config_prefix => sub { 'biox_map' };

=head2 infile

input file

=cut

option infile => (
  is        => 'ro',
  format    => 's',
  short     => 'i',
  doc       => "path of one fastq file",
);

=head2 outfile

outfile

=cut

option outfile => (
  is        => 'ro',
  format    => 's',
  short     => 'o',
  doc       => "path of outfile",
);

=head2 indir

input dir that include multiple samples

=cut

option indir => (
  is        => 'ro',
  format    => 's',
  short     => 'I',
  default   => '',
  doc       => "path of one fastq file",
);

=head2 outdir

output dir 

=cut

option outdir => (
  is        => 'ro',
  format    => 's',
  short     => 'O',
  doc       => "path of one fastq file",
  default   => './',
);

=head2 process_tool

process number used by soap or bwa

=cut

option process_tool => (
  is        => 'ro',
  format    => 'i',
  short     => 'p',
  doc       => "path of outfile",
  default   => 1,
);

=head2 process_sample

process number used when there are many samples

=cut

option process_sample => (
  is        => 'ro',
  format    => 'i',
  short     => 'P',
  doc       => "path of outfile",
  default   => 1,
);

=head2 genome

path of genome file

=cut

option genome => (
  is        => 'ro',
  format    => 's',
  short     => 'g',
  required  => 1,
  doc       => "path of genome file",
);

=head2 tool

soap or bwa

=cut

option tool => (
  is        => 'ro',
  isa       => Enum['soap', 'bwa'],
  format    => 's',
  short     => 't',
  required  => 1,
  default   => 'soap',
  doc       => "mapping software",
);

=head2 execute

=head2 BUILDARGS

=cut

sub execute {
  my ($self, $args_ref, $chain_ref) = @_;
  my $pre_message = "please input parameters, genome is required, either infile or indir is required";
  my ($infile, $indir, $outfile, $outdir) = ($self->infile, $self->indir, $self->outfile, $self->outdir);
  $self->options_usage(1, $pre_message) unless ($infile or $indir);
  my ($genome, $tool, $process_tool, $process_sample) = ($self->genome, $self->tool, $self->process_tool, $self->process_sample);
  my $bm = BioX::Map->new(
    infile          => $infile,
    indir           => $indir,
    outfile         => $outfile,
    outdir          => $outdir,
    genome          => $genome,
    tool            => $tool,
    process_tool    => $process_tool,
    process_sample  => $process_sample,
  );
  $bm->map;
}

1;



