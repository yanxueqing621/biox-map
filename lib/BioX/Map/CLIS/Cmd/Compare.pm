package BioX::Map::CLIS::Cmd::Compare;
use Modern::Perl;
use IO::All;
use Carp "confess";
use Moo;
use MooX::Options prefer_commandline => 1, with_config_from_file => 1;
use MooX::Cmd;
use BioX::Map;
use Types::Standard qw(Int Str Bool Enum);
use Parallel::ForkManager;

# VERSION:
# ABSTRACT: a wrapper for mapping software

=head1 DESCRIPTION

  used to mapped a or more sample.

=head1 SYNOPSIS

  use BioX::Map::CLIS::Cmd::Compare;
  BioX::Map::CLIS::Cmd::Map->new_with_cmd;

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
  doc       => "path of one fastq file",
);


=head2 soap_suffix

suffix of all samples' soap result

=cut

option soap_suffix => (
  is        => 'ro',
  format    => 's',
  short     => 's',
  doc       => "suffix of all samples' soap result",
  default   => 'soap',
);

=head2 bwa_suffix

suffix of all samples' bwa result

=cut

option bwa_suffix => (
  is        => 'ro',
  format    => 's',
  short     => 'b',
  doc       => "suffix of all samples' bwa result",
  default   => 'bwa',
);

=head2 process

number of process will be used

=cut

option process => (
  is      => 'ro',
  format  => 's',
  short   => 'p',
  doc     => 'number of process will be used',
  default => 2,

);

=head2 outfile

summary file

=cut

option outfile => (
  is        => 'ro',
  format    => 's',
  short     => 'o',
  default   => 'summary.txt',
  doc       => "file used to store summary file",
);

=head2 execute

=head2 BUILDARGS

=cut

sub execute {
  my ($self, $args_ref, $chain_ref) = @_;
  my $pre_message = "please input parameters, genome is required, either infile or indir is required";
  my ($indir, $outfile, $soap_suffix, $bwa_suffix) = ($self->indir, $self->outfile,  $self->soap_suffix, $self->bwa_suffix);
  $self->options_usage(1, $pre_message) unless ($outfile and $indir and $soap_suffix and $bwa_suffix);
  my $bm = BioX::Map->new;
  say "indir:$indir";
  my @soap_result = io($indir)->filter( sub {$_->filename =~/\.$soap_suffix$/} )->all_files;
  my @bwa_result = io($indir)->filter( sub {$_->filename =~/\.$bwa_suffix$/} )->all_files;
  $outfile = io($outfile);
  $outfile->print("samplename\tsoap0\tsoap1\tsoap2\tbwa0\tbwa1\tbwa2\n");
  my $pm = Parallel::ForkManager->new($self->process);
  DATA_LOOP:
  for my $sr (@soap_result) {
    my $pid = $pm->start and next DATA_LOOP;
    $bm->tool("soap");
    my $filename = $sr->filename;
    say "###########sr: $sr ######filename: $filename";
    $filename =~s/\.$soap_suffix$//i;
    say "soap result:$sr";
    my $s_r = $bm->statis_result("$sr");
    $bm->tool("bwa");
    $sr =~s/$soap_suffix$/$bwa_suffix/i;
    say "bwa result:$sr";
    my $b_r = $bm->statis_result("$sr");
    $sr =~s/\.$bwa_suffix//i;
    $outfile->lock->println(join "\t", $filename, @$s_r, @$b_r)->unlock;
    $pm->finish;
  }
  $pm->wait_all_children;
}

1;
