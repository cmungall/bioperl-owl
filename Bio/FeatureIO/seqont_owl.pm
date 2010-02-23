=pod

=head1 NAME

Bio::FeatureIO::seqont_owl - write Sequence Ontology conformant OWL files

=head1 SYNOPSIS

  my $feature; #get a Bio::SeqFeature::Annotated somehow
  my $featureOut = Bio::FeatureIO->new(
    -format => 'seqont_owl',
    -version => 3,
    -fh => \*STDOUT,
  );
  $featureOut->write_feature($feature);

=head1 DESCRIPTION

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to
the Bioperl mailing list.  Your participation is much appreciated.

  bioperl-l@bioperl.org                 - General discussion
  http://bioperl.org/wiki/Mailing_list  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
of the bugs and their resolution. Bug reports can be submitted via
the web:

  http://bugzilla.open-bio.org/

=head1 AUTHOR

 Chris Mungall

=head1 CONTRIBUTORS


=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::FeatureIO::seqont_owl;
use strict;

#these are alphabetical, keep them that way.
use Bio::Annotation::DBLink;
use Bio::Annotation::OntologyTerm;
use Bio::Annotation::SimpleValue;
use Bio::Annotation::Target;
use Bio::FeatureIO;
use Bio::Ontology::OntologyStore;
use Bio::OntologyIO;
use Bio::SeqFeature::Annotated;
use Bio::SeqIO;
use URI::Escape;
use XML::Writer;

use base qw(Bio::FeatureIO);

my $RESERVED_TAGS   = "ID|Name|Alias|Parent|Target|Gap|Derives_from|Note|Dbxref|dbxref|Ontology_term|Index|CRUD";

use constant RDF => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#';
use constant RDFS => 'http://www.w3.org/2000/01/rdf-schema#';
use constant OWL => 'http://www.w3.org/2002/07/owl#';
use constant SO => 'http://purl.org/obo/owl/SO#';


sub _initialize {
  my($self,%arg) = @_;

  $self->SUPER::_initialize(%arg);

  $self->{_enumerate_junctions} =  $arg{-enumerate_junctions} || 0;
  #$self->version( $arg{-version}        || DEFAULT_VERSION);
  #$self->validate($arg{-validate_terms} || 0);

  if ($arg{-file} =~ /^>.*/ ) {
      #$self->_print("##seqont_owl-version " . $self->version() . "\n");
  }
  else {
    my $directive;
    while(($directive = $self->_readline()) && ($directive =~ /^##/) ){
      $self->_handle_directive($directive);
    }
    $self->_pushback($directive);
  }
  # TODO - make this configurable
  $self->{_label_to_id_map} = require 'Bio/FeatureIO/types.pl'; 
  $self;
}

=head2 _create_writer

=over

=item Usage

  $obj->_create_writer()

=item Function

Creates XML::Writer object and writes start tag

=item Returns

Nothing, though the writer persists as part of the chadoxml object

=item Arguments

None

=back

=cut

sub _create_writer {
    my $self = shift;

    $self->{'writer'} = 
        new XML::Writer(OUTPUT => $self->_fh,
                        NAMESPACES => 1,
                        DATA_MODE => 1,
                        DATA_INDENT => 2,
                        PREFIX_MAP => {(RDF,'rdf'),
                                       (RDFS,'rdfs'),
                                       (OWL,'owl'),
                                       (SO,'so'),
                        },
                        FORCED_NS_DECLS=>[RDF,RDFS,OWL,SO],
                        
        );

    #print header
    $self->{'writer'}->xmlDecl("UTF-8");
    $self->{'writer'}->comment("Sequence Ontology conformant OWL");

    #start chadoxml
    $self->{'writer'}->startTag([RDF,'RDF']);

    $self->{'writer'}->startTag([OWL,'Ontology'], [RDF,'about']=>$self->namespace);

    if (0) {
	# TODO: configurable
	$self->{'writer'}->startTag([OWL,'imports'], [RDF,'resource']=>"file:///Users/cjm/cvs/song/ontology/working_draft.owl");  # temporary URL
	$self->{'writer'}->endTag([OWL,'imports']);

	# TODO: configurable
	$self->{'writer'}->startTag([OWL,'imports'], [RDF,'resource']=>"file:///Users/cjm/cvs/song/ontology/working_draft-ecs.owl");  # temporary URL
	$self->{'writer'}->endTag([OWL,'imports']);

	$self->{'writer'}->startTag([OWL,'imports'], [RDF,'resource']=>"file:///Users/cjm/cvs/song/ontology/gia_i.owl");  # temporary URL
	$self->{'writer'}->endTag([OWL,'imports']);
    }
    if (1) {
	$self->{'writer'}->startTag([OWL,'imports'], [RDF,'resource']=>"http://purl.org/obo/owl/so_ext_all");  # temporary URL
	$self->{'writer'}->endTag([OWL,'imports']);
    }


    $self->{'writer'}->endTag([OWL,'Ontology']);

    $self->{_exported_junction_h} = {};

    return $self->{writer};
}

sub _destroy_writer {
    my $self = shift;
    $self->writer->endTag([RDF,'RDF']) if $self->writer;
}

sub DESTROY {
    my $self = shift;
    if ($self->{_enumerate_junctions}) {
        $self->write_all_junctions;
    }
    $self->_destroy_writer;
}

sub writer {
    my $self = shift;
    return $self->{writer};
}

sub namespace {
    my $self = shift;
    $self->{_namespace} = shift if @_;
    if (!$self->{_namespace}) {
        return "http://x.org#"; # default
    }
    return $self->{_namespace};
}

sub uri {
    my $self = shift;
    my $id = shift;
    if (!$id) {
	$self->throw("must pass id");
    }
    if (ref($id)) {
	if (ref($id->primary_id)) {
	    # $id is feature object
	    $id = $id->primary_id;
	}
	else {
	    return;
	}
    }
    return $self->namespace . "$id";
}

sub so_uri {
    my $self = shift;
    my $type = shift;
    if (ref($type)) {
        $type = $type->name;
    }
    my $id = $self->{_label_to_id_map}->{$type};
    if ($id) {
	$type = $id;
    }
    return SO . $type;
}

sub rel_uri {
    my $self = shift;
    my $type = shift;
    return $self->uri($type);
}

=head2 write_feature()

 Usage   : $featureio->write_feature( Bio::SeqFeature::Annotated->new(...) );
 Function: writes a feature in OWL format.  
 Returns : ###FIXME
 Args    : a Bio::SeqFeature::Annotated object.

=cut

sub write_feature {
  my($self,$feature) = @_;
  if (!$feature) {
    $self->throw("seqont_owl.pm cannot write_feature unless you give a feature to write.\n");
  }
  $self->throw("only Bio::SeqFeature::Annotated objects are writeable") unless $feature->isa('Bio::SeqFeature::Annotated');

  my $w = $self->writer;

  if (!$w) {
      $w = $self->_create_writer();
  }

  my ($sj,$ej) = $self->_junctions($feature);

  my $uri = $self->uri($feature);
  my @about = ();
  if ($uri) {
      @about = ([RDF,'about']=>$uri);
  }
  $w->startTag([RDF,'Description'],@about);
  $w->startTag([RDF,'type'],[RDF,'resource']=>$self->so_uri($feature->type));
  $w->endTag([RDF,'type']);
  my @v = ($feature->get_Annotations('Name'));
  foreach (@v) {
      $w->startTag([RDFS,'label'],[RDF,'datatype']=>'string');
      $w->characters($_->value);
      $w->endTag([RDFS,'label']);
  }

  $w->startTag([SO,'starts_on'],[RDF,'resource']=>$self->uri($sj));
  $w->endTag([SO,'starts_on']);
  $w->startTag([SO,'ends_on'],[RDF,'resource']=>$self->uri($ej));
  $w->endTag([SO,'ends_on']);
  # TODO: additional metadata
  $w->endTag([RDF,'Description']);

}

sub _junctions {
    my($self,$feature) = @_;
  
    # convert to interbase here
    my $sj = $self->_junction($feature->seq_id,$feature->start-1,$feature->strand);
    my $ej = $self->_junction($feature->seq_id,$feature->end,$feature->strand);
    return ($sj,$ej);
}

sub _junction {
  my($self,$seq_id,$jpos,$strand) = @_;

  if (!$strand) {
      $strand = 1;
  }

  my $jid = sprintf("%s__%s__%s",$seq_id,$jpos,$strand);

  if (!$self->{_leftmost}) {
      $self->{_leftmost} = {};
  }
  if (!$self->{_rightmost}) {
      $self->{_rightmost} = {};
  }

  if (!defined($self->{_leftmost}->{$seq_id}) || 
      $jpos < $self->{_leftmost}->{$seq_id}) {
      $self->{_leftmost}->{$seq_id} = $jpos;
  }
  if (!defined($self->{_rightmost}->{$seq_id}) || 
      $jpos > $self->{_rightmost}->{$seq_id}) {
      $self->{_rightmost}->{$seq_id} = $jpos;
  }

  my $jh = $self->{_exported_junction_h};
  if (!$jh->{$jid}) {
      my $w = $self->writer;
      $w->startTag([RDF,'Description'],[RDF,'about']=>$self->uri($jid));
      $w->startTag([RDF,'type'],[RDF,'resource']=>$self->so_uri('junction'));
      $w->endTag([RDF,'type']);
      $w->startTag([SO,'in_sequence'],[RDF,'resource']=>$self->uri($seq_id));
      $w->endTag([SO,'in_sequence']);
      $w->startTag([SO,'number_of_upstream_bases'],[RDF,'datatype']=>'integer');
      $w->characters($jpos);
      $w->endTag([SO,'number_of_upstream_bases']);
      $w->endTag([RDF,'Description']);
      $jh->{$jid} = 1;
  }
  return $jid;
}

=head2 write_all_junctions

If we want to reason from first principles using an OWL reasoner, we
cannot use arithmetic. Instead we enumerate all bases on each strand
and add immediately_before relations between them.

=cut

sub write_all_junctions {
    my $self = shift;
    my $w = $self->writer;
    foreach my $seq_id (keys %{$self->{_leftmost}}) {
        my $start = $self->{_leftmost}->{$seq_id};
        my $end = $self->{_rightmost}->{$seq_id};
        for (my $i=$start; $i <= $end; $i++) {
            my $jid = $self->_junction($seq_id,$i,1);
            my $rjid = $self->_junction($seq_id,$i,-1);
            my $jid_next = $self->_junction($seq_id,$i+1,1);
            my $rjid_next = $self->_junction($seq_id,$i-1,-1);

            $w->startTag([RDF,'Description'],[RDF,'about']=>$self->uri($jid));
            $w->startTag([SO,'immediately_before'],[RDF,'resource']=>$self->uri($jid_next));
            $w->endTag([SO,'immediately_before']);
            $w->endTag([RDF,'Description']);
            
            $w->startTag([RDF,'Description'],[RDF,'about']=>$self->uri($rjid));
            $w->startTag([SO,'immediately_before'],[RDF,'resource']=>$self->uri($rjid_next));
            $w->endTag([SO,'immediately_before']);
            $w->endTag([RDF,'Description']);
            
        }
    }
}


################################################################################

=head1 ACCESSORS

=cut

=head2 fasta_mode()

 Usage   : $obj->fasta_mode($newval)
 Function: 
 Example : 
 Returns : value of fasta_mode (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub fasta_mode {
  my($self,$val) = @_;
  $self->{'fasta_mode'} = $val if defined($val);
  return $self->{'fasta_mode'};
}

=head2 seqio()

 Usage   : $obj->seqio($newval)
 Function: holds a Bio::SeqIO instance for handling the SEQONT_OWL3 ##FASTA section.
 Returns : value of seqio (a scalar)
 Args    : on set, new value (a scalar or undef, optional)


=cut

sub seqio {
  my($self,$val) = @_;
  $self->{'seqio'} = $val if defined($val);
  return $self->{'seqio'};
}

=head2 sequence_region()

 Usage   :
 Function: ###FIXME
 Returns : 
 Args    :


=cut

sub sequence_region {
  my ($self,$k,$v) = @_;
  if(defined($k) && defined($v)){
    $self->{'sequence_region'}{$k} = $v;
    return $v;
  }
  elsif(defined($k)){
    return $self->{'sequence_region'}{$k};
  }
  else {
    return;
  }
}


=head2 so()

 Usage   : $obj->so($newval)
 Function: holds a Sequence Ontology instance
 Returns : value of so (a scalar)
 Args    : on set, new value (a scalar or undef, optional)

=cut

sub so {
  my $self = shift;
  my $val = shift;
  ###FIXME validate $val object's type
  $self->{so} = $val if defined($val);
  return $self->{so};
}


1;
