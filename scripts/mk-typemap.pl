#!/usr/bin/perl

use GOBO::Graph;
use GOBO::Statement;
use GOBO::LinkStatement;
use GOBO::NegatedStatement;
use GOBO::Node;
use GOBO::Parsers::OBOParser;
use GOBO::Writers::OBOWriter;
use Data::Dumper;
use FileHandle;

my $outfmt = 'obo';
while (scalar(@ARGV) && $ARGV[0] =~ /^\-/) {
    my $opt = shift @ARGV;
}

my $f = shift;
my $parser = new GOBO::Parsers::OBOParser(file=>$f);
$parser->parse;
my $g = $parser->graph;
my $h = {};
foreach my $t (@{$g->terms}) {
    $h->{$t->label} = $t->id;
}
print Dumper($h);
