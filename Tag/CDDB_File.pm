package MP3::Tag::CDDB_File;

use strict;
use File::Basename;
use File::Spec;
use vars qw /$VERSION @ISA/;

$VERSION="0.01";
@ISA = 'MP3::Tag::__hasparent';

=pod

=head1 NAME

MP3::Tag::CDDB_File - Module for parsing CDDB files.

=head1 SYNOPSIS

  my $db = MP3::Tag::CDDB_File->new($filename, $track);	# Name of MP3 file
  my $db = MP3::Tag::CDDB_File->new_from($record, $track); # Contents of CDDB 

  ($title, $artist, $album, $year, $comment, $track) = $db->parse();

see L<MP3::Tag>

=head1 DESCRIPTION

MP3::Tag::Inf is designed to be called from the MP3::Tag module.

It parses the content of CDDB file.

The file is found in the same directory as MP3 file; the list of possible
file names is taken from the field C<cddb_files> if set by MP3::Tag config()
method.

=over 4

=cut


# Constructor

sub new_from {
    my ($class, $data, $track) = @_;
    bless {data => [split /\n/, $data], track => $track}, $class;
}

sub new_setdir {
    my $class = shift;
    my $filename = shift;
    $filename = $filename->filename if ref $filename;
    $filename = dirname($filename);
    return bless {dir => $filename}, $class;	# bless to enable get_config()
}

sub new_fromdir {
    my $class = shift;
    my $h = shift;
    my $dir = $h->{dir};
    my $found;
    my $l = $h->get_config('cddb_files');
    for my $file (@$l) {
	my $f = File::Spec->catdir($dir, $file);
	$found = $f, last if -r $f;
    }
    return unless $found;
    local *F;
    open F, "< $found" or die "Can't open `$found': $!";
    my @data = <F>;
    close F or die "Error closing `$found': $!";
    bless {filename => $found, data => \@data, track => shift,
	   parent => $h->{parent}}, $class;    
}

sub new {
    my $class = shift;
    my $h = $class->new_setdir(@_);
    $class->new_fromdir($h);
}

sub new_with_parent {
    my ($class, $filename, $parent) = @_;
    my $h = $class->new_setdir($filename);
    $h->{parent} = $parent;
    $class->new_fromdir($h);
}

# Destructor

sub DESTROY {}

=item parse()

  ($title, $artist, $album, $year, $comment, $track) =
     $db->parse($what);

parse_filename() extracts information about artist, title, track number,
album and year from the CDDB record.  $what is optional; it maybe title,
track, artist, album, year or comment. If $what is defined parse() will return
only this element.

=cut

sub return_parsed {
    my ($self,$what) = @_;
    if (defined $what) {
	return $self->{parsed}{album}  if $what =~/^al/i;
	return $self->{parsed}{artist} if $what =~/^a/i;
	return $self->{parsed}{track}  if $what =~/^tr/i;
	return $self->{parsed}{year}   if $what =~/^y/i;
	return $self->{parsed}{comment}if $what =~/^c/i;
	return $self->{parsed}{genre}  if $what =~/^g/i;
	return $self->{parsed}{title};
    }
    
    return $self->{parsed} unless wantarray;
    return map $self->{parsed}{$_} , qw(title artist album year comment track);
}

my %r = ( 'n' => "\n", 't' => "\t", '\\' => "\\"  );

sub parse_lines {
    my ($self) = @_;
    return if $self->{fields};
    for my $l (@{$self->{data}}) {
	next unless $l =~ /^\s*(\w+)\s*=\s*(.*)/;
	$self->{fields}{$1} = "" unless exists $self->{fields}{$1};
	$self->{fields}{$1} .= $2;
	$self->{last} = $1 if $1 =~ /\d+$/;
    }    
    s/\\([nt\\])/$r{$1}/g for values %{$self->{fields}};
}

sub parse {
    my ($self,$what) = @_;
    return $self->return_parsed($what)	if exists $self->{parsed};
    $self->parse_lines;
    my %parsed;
    my ($t1, $c1, $t2, $c2) = map $self->{fields}{$_}, qw(DTITLE EXTD);
    my $track = $self->track;
    if ($track) {
	my $t = $track - 1;
	($t2, $c2) = map $self->{fields}{$_}, "TTITLE$t", "EXTT$t";
    }
    my ($a, $t, $aa, $tt);
    ($a, $t) = split /\s+\/\s+/, $t1, 2 if defined $t1;
    ($a, $t) = ($t, $a) unless defined $t;
    ($aa, $tt) = split /\s+\/\s+/, $t2, 2 if defined $t2;
    ($aa, $tt) = ($tt, $aa) unless defined $tt;
    $aa = $a unless defined $aa and length $aa;
    undef $aa if defined $aa and $aa =~ 
	/^\s*(<<\s*)?(Various Artists|compilation disc)\s*(>>\s*)?$/i;
    $tt = $t unless defined $tt and length $tt;
    if (defined $c2 and length $c2) { # Merge unless one is truncation of another
	if ( defined $c1 and length $c1
	     and $c1 ne substr $c2, 0, length $c1
	     and $c1 ne substr $c2, -length $c1 ) {
	    $c2 =~ s/[.,:;]$//;
	    $c1 = "$c2; $c1";
	} else {
	    $c1 = $c2;
	}
    }
    @parsed{ qw( title artist album year comment track genre) } =
	($tt, $aa, $t, $self->{fields}{DYEAR}, $c1, $track,
	 $self->{fields}{DGENRE});
    $self->{parsed} = \%parsed;
    $self->return_parsed($what);
}


=pod

=item title()

 $title = $db->title();

Returns the title, obtained from the C<'Tracktitle'> entry of the file.

=cut

*song = \&title;

sub title {
    return shift->parse("title");
}

=pod

=item artist()

 $artist = $db->artist();

Returns the artist name, obtained from the C<'Performer'> or
C<'Albumperformer'> entries (the first which is present) of the file.

=cut

sub artist {
    return shift->parse("artist");
}

=pod

=item track()

 $track = $db->track();

Returns the track number, stored during object creation.

=cut

sub track {
  my $self = shift;
  return $self->{track} if defined $self->{track};
  return if $self->{recursive} or not $self->parent_ok;
  local $self->{recursive} = 1;
  return $self->{parent}->track;
}

=item year()

 $year = $db->year();

Returns the year, obtained from the C<'Year'> entry of the file.  (Often
not present.)

=cut

sub year {
    return shift->parse("year");
}

=pod

=item album()

 $album = $db->album();

Returns the album name, obtained from the C<'Albumtitle'> entry of the file.

=cut

sub album {
    return shift->parse("album");
}

=item comment()

 $comment = $db->comment();

Returns the C<'Trackcomment'> entry of the file.  (Often not present.)

=cut

sub comment {
    return shift->parse("comment");
}

=item genre()

 $genre = $db->genre($filename);

=cut

sub genre {
    return shift->parse("genre");
}

1;
