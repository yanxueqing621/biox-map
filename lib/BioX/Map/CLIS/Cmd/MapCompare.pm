package BioX::Map::CLIS::Cmd::MapCompare;
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

  use BioX::Map::CLIS::Cmd::MapCompare;
  BioX::Map::CLIS::Cmd::MapCompare->new_with_cmd;

=head1 Attribute

=cut

around _build_config_identifier => sub { 'berry' };
around _build_config_prefix => sub { 'biox_map' };


=head2 indir

input dir that include multiple samples

=cut

option indir => (
  is        => 'ro',
  format    => 's',
  short     => 'i',
  default   => '',
  doc       => "path of indir include fastq files",
);

=head2 outdir

output dir

=cut

option outdir => (
  is        => 'ro',
  format    => 's',
  short     => 'o',
  doc       => "path of output dir include mapping result",
  default   => './',
);

=head2 summary_file

path of summary_file

=cut

option summary_file => (
  is        => 'ro',
  format    => 's',
  short     => 's',
  doc       => 'path of summary file',
  default   => "summary.txt",
);

=head2 process_tool

process number used by soap or bwa

=cut

option process_tool => (
  is        => 'ro',
  format    => 'i',
  short     => 'p',
  doc       => "cpu number used by soap or bwa",
  default   => 1,
);

=head2 process_sample

process number used when there are many samples

=cut

option process_sample => (
  is        => 'ro',
  format    => 'i',
  short     => 'P',
  doc       => "number of samples running parallel",
  default   => 1,
);

=head2 genome

path of genome file

=cut

option genome => (
  is        => 'ro',
  format    => 's',
  short     => 'g',
  doc       => "path of genome file",
  required  => 1,
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
  my $stamp = time;
  my $pre_message = "please input parameters, indir is required";
  my ($indir, $outdir) = ($self->indir, $self->outdir);
  $self->options_usage(1, $pre_message) unless ( $indir);
  my ($genome, $tool, $process_tool, $process_sample) = ($self->genome, $self->tool, $self->process_tool, $self->process_sample);
  my $bm = BioX::Map->new(
    indir           => $indir,
    outdir          => $outdir,
    genome          => $genome,
    tool            => $tool,
    process_tool    => $process_tool,
    process_sample  => $process_sample,
  );
  $bm->map;
  $bm->tool('bwa');
  $bm->map;
  my $summary = $self->summary_file;
  system("biox-map compare -i $outdir -o $summary -s soap -b bwa");
  my $m = time - $stamp;
  say "duration second" . (time - $stamp) . "\nduration minute" . (int ($m / 60));
}

1;



