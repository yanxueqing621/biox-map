package BioX::Map;
use Modern::Perl;
use IO::All;
use Moo;
use Carp qw/confess/;
use Types::Standard qw/Str Int Enum Bool/;
use File::Which;
use Cwd;
use IPC::Run qw/run timeout/;
use Parallel::ForkManager;
use File::ShareDir ":ALL";

# VERSION
# ABSTRACT: map read to genome with bwa and soap

=head1 SYNOPSIS

  use BioX::Map;
  my $bm = BioX::Map->new(
    infile      => "in.fastq",
    out_prefix  => 'out',
    genome      => 'ref.fa',
  );

=head1 DESCRIPTION

This module aim to wrap bwa and soap, and statistic result

=head1 Attributes

=cut

=head2 infile

the fastq file

=cut

has infile => (
  is      => "ro",
  isa     => Str,
  default => '',
);

=head2 indir

The dir that include fastq file. The priority is higher than infile

=cut

has indir => (
  is      => 'ro',
  isa     => Str,
);

=head2 outfile

path of outfile which could include path

=cut

has outfile => (
  is      => 'lazy',
  isa     => Str,
);

=head2 outdir

outdir of mapping result

=cut

has outdir => (
  is        => 'lazy',
  isa       => Str,
  default   => "./",
);

=head2 force_index

index genome before mapping

=cut

has force_index => (
  is      => 'lazy',
  isa     => Bool,
  default => 0,
);

=head2 mismatch

set mismatch allowed in mapping

=cut

has mismatch => (
  is      => 'lazy',
  isa     => Int,
  default => 2,
);

=head2 genome

path of genome file

=cut

has genome => (
  is      => 'ro',
  isa     => Str,
);

=head2 tool

mapping software. Enum['bwa', 'soap']

=cut

has tool => (
  is      => 'rw',
  isa     => Enum['bwa', 'soap'],
  default => "soap",
);

=head2 bwa

path of bwa

=cut

has bwa => (
  is      => "lazy",
  isa     => Str,
  default => sub { dist_file('BioX-Map', 'exe/bwa') },
);

=head2 soap

path of soap

=cut

has soap  => (
  is      => "lazy",
  isa     => Str,
  default => sub { dist_file('BioX-Map', 'exe/soap') },
);

=head2 soap_index

path of 2bwt-builder

=cut

has soap_index  => (
  is      => "lazy",
  isa     => Str,
  default => sub { dist_file('BioX-Map', 'exe/2bwt-builder') },
);

=head2 process_tool

process of mapping software

=cut

has process_tool => (
  is      => 'ro',
  isa     => Int,
  default => 1,
);

=head2 process_sample

how many samples are processed parallel

=cut

has process_sample => (
  is      => 'ro',
  isa     => Int,
  default => 1,
);

sub _build_outfile {
  my $self = shift;
  my $infile = io($self->infile);
  return $infile->exists ? io->catfile($ENV{PWD},  $infile->filename . "." . $_[0]->tool) : '';
}

=head2 exist_index

check whether genome index exists

=cut

sub exist_index {
  my $self = shift;
  my ($tool, $genome) = ($self->tool, $self->genome);
  my @soap_suffix = qw/amb ann bwt fmv hot lkt pac rev.bwt rev.fmv rev.lkt rev.pac/;
  my @bwa_suffix = qw/amb ann bwt pac sa/;
  my $flag = 1;
  if ($tool eq 'soap') {
    for my $suffix (@soap_suffix) {
      $flag = 0 unless (-e "$genome.index.$suffix");
    }
  } elsif ($tool eq 'bwa') {
    for my $suffix (@bwa_suffix) {
      $flag = 0 unless (-e "$genome.bwa.$suffix");
    }
  }
  return $flag;
}

=head2 create_index

create genome index before mapping

=cut

sub create_index {
  my $self = shift;
  my ($tool, $genome) = ($self->tool, $self->genome);
  my ($soap, $bwa, $soap_index) = ($self->soap, $self->bwa, $self->soap_index);
  confess "$genome is not exist" unless -e $genome;
  my $genome_dir = io($genome)->filepath;
  my $genome_name = io($genome)->filename;
  chdir("$genome_dir");
  my @cmd = $tool eq 'soap' ? ($soap_index, $genome_name)
          : $tool eq 'bwa'  ? ($bwa, 'index', '-a', 'bwtsw', '-p', "$genome_name.bwa",  "$genome_name")
          :                   ();
  if (@cmd) {
    my ($in, $out, $err);
    say join(" ", @cmd);
    run \@cmd, \$in, \$out, \$err or confess "cat $?: $err";
    chdir($ENV{'PWD'});
    return $self->exist_index ? 1 : 0;
  }
}

=head2 _map_one

wrap mapping software

=cut

sub _map_one {
  my ($self, $infile, $outfile) = @_;
  $infile ||= $self->infile;
  $outfile ||= $self->outfile;
  say "infile:$infile. outfile:$outfile";
  my ($tool, $genome, $mismatch) = ($self->tool, $self->genome, $self->mismatch);
  my ($soap, $bwa, $process_tool) = ($self->soap, $self->bwa, $self->process_tool);
  $self->create_index if ($self->exist_index == 0 || $self->force_index);
  my $genome_index = $tool eq 'soap' ? "$genome.index"
                   : $tool eq 'bwa'  ? "$genome.bwa"
                   :                   '';
  my ($in, $out, $err, @cmd);
  if ($tool eq 'soap') {
    @cmd = ($soap, "-a", $infile, "-p", $process_tool, "-D", $genome_index, "-o", "$outfile");
    say join(" ", @cmd);
    run \@cmd, \$in, \$out, \$err or confess "cat $?: $err";
    return $err ? 0 : 1;
  } elsif ($tool eq 'bwa') {
    @cmd = ($bwa, "aln", "-n", $mismatch, "-t", $process_tool, "-f", "$outfile.sai", $genome_index, $infile);
    say join(" ", @cmd);
    run \@cmd, \$in, \$out, \$err or confess "cat $?: $err";
    #return $err ? 0 : 1;
    @cmd = ($bwa, "samse", "-f", "$outfile", $genome_index, "$outfile.sai", "$infile");
    say join(" ", @cmd);
    run \@cmd, \$in, \$out, \$err or confess "cat $?: $err";
    #return $err ? 0 : 1;
  }
}

=head2 map

process one or more samples

=cut

sub map {
  my $self = shift;
  my ($infile, $indir, $outfile, $outdir) = ($self->infile, $self->indir, $self->outfile, $self->outdir);
  my ($genome, $tool, $process_sample) = ($self->genome, $self->tool, $self->process_sample);
  if ($indir) {
    my @fqs = io($indir)->filter(sub {$_->filename =~/fastq|fq$/})->all_files;
    return 0 unless (@fqs);
    io($outdir)->mkpath unless -e $outdir;
    my $pm = Parallel::ForkManager->new($process_sample);
    DATA_LOOP:
    for my $fq (@fqs) {
      my $pid = $pm->start and next DATA_LOOP;
      my $fq_name = $fq->filename;
      $self->_map_one($fq, io->catfile($outdir, "$fq_name.$tool")->pathname);
      $pm->finish;
    }
    $pm->wait_all_children;
  } elsif ($infile) {
    confess "$infile is not exist" unless -e $infile;
    $self->_map_one;
  }
}

=head2 statis_result

statis mapping result

=cut

sub statis_result {
  my ($self, $align_result) = @_;
  my ($tool, $outfile) = ($self->tool, $self->outfile);
  $outfile = $align_result || $outfile;
  $outfile = io($outfile);
  confess "$outfile is not exist" unless $outfile->exists;
  my @result = (0, 0, 0);
  if ($tool eq "soap") {
    while (defined (my $line = $outfile->getline)) {
      my @cols = split /\t/, $line;
      next unless $cols[3] == 1;
      $result[0]++ if ($cols[9] == 0);
      $result[1]++ if ($cols[9] =~/^[01]$/);
      $result[2]++ if ($cols[9] =~/^[012]$/);
    }
  } elsif ($tool eq 'bwa') {
    while (defined (my $line = $outfile->getline)) {
      my @cols = split /\t/, $line;
      next if $line =~/^@/;
      next if @cols == 11;
      next unless $cols[11] eq 'XT:A:U';
      $result[0]++ if ($cols[12] eq 'NM:i:0');
      $result[1]++ if ($cols[12] =~/NM:i:[01]/);
      $result[2]++ if ($cols[12] =~/NM:i:[012]/);
    }
  }
  return \@result;
}

1;
