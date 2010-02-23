#!perl -w

use strict;
use Getopt::Long;
use Bio::FeatureIO;

my $help;
my $from='gff';
my $to=undef;

my %opt = ();
if (@ARGV && $ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
    if ($opt eq '-f' || $opt eq '--from') {
	$from = shift @ARGV;
    }
    if ($opt eq '-j' || $opt eq '--enumerate-junctions') {
        $opt{'-enumerate_junctions'} = 1;
    }
    else {
        die $opt;
    }
}

my $script=substr($0, 1+rindex($0,'/'));
my $usage="Usage:

  $script --from in-format < file.in-format > ";


my $in  = Bio::FeatureIO->newFh(-fh => \*STDIN , '-format' => $from);
my $out = Bio::FeatureIO->newFh(-fh=> \*STDOUT, '-format' => 'seqont_owl',     
                                %opt
);

print STDERR "parsing: $in\n";
foreach (<$in>) {
    print $out $_;

}
#$out->_destroy_writer;

__END__

=head1 NAME

gff2owl - converts gff to owl

=head1 SYNOPSIS

  gff2owl [--from in-format] [--enumerate-junctions] < file.in-format > file.owl

=head1 DESCRIPTION

Generates OWL from a feature format (defaults to GFF)

=head2 OPTIONS

  --enumerate-junctions
   -j                     materialize all interbase junctions

materializing junctions is for enabling reasoning using Allen interval
relations within OWL. We cannot define relations such as upstream_of
using datatypes.

note this option is (possibly prohibitively expensive) for large
genomes (or even small ones). This is mainly for evaluation purposes
(see forthcoming paper).

=head1 SEE ALSO

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via the
web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR - Chris Mungall

=cut

__END__
