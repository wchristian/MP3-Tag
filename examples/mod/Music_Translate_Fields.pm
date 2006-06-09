package Music_Translate_Fields;
use strict;

my %tr;
my %short;

sub translate_dots ($) {
  my $a = shift;
  $a =~ s/^\s+//;
  $a =~ s/\s+$//;
  $a =~ s/\s+/ /g;
  $a =~ s/\b(\w)\.\s*/$1 /g;
  $a =~ s/(\w\.)\s*/$1 /g;
  lc $a
}

sub translate_tr ($) {
  my $a = shift;
  $a = $tr{translate_dots $a} or return;
  return $a;
}

sub strip_years ($) {		# strip dates
  my ($a) = (shift);
  my @rest;
  return $a unless $a =~ s/\s+((?:\([-\d,]+\)(\s+|$))+)$//;
  @rest = split /\s+/, $1;
  return $a, @rest;
}

sub strip_duplicate_dates {	# Remove $d[0] if it matches $d_r
  my ($d_r, @d) = @_;
  return unless @d;
  $d_r   = substr $d_r,  1, length($d_r)  - 2; # Parens
  my $dd = substr $d[0], 1, length($d[0]) - 2; # Parens
  my @dates_r = split /,|--|-(?=\d\d\d\d)/, $d_r;
  my @dates   = split /,|--|-(?=\d\d\d\d)/, $dd;
  for my $d (@dates) {
    return @d unless grep /^\Q$d\E(-|$)/, @dates_r;
  }
  return @d[1..$#d];
}

sub __split_person ($) {
  # Non-conflicting ANDs (0x438 is cyrillic "i", word is cyrillic "per")
  split /([,;:]\s+(?:\x{043f}\x{0435}\x{0440}\.\s+)?|\s+(?:[-&\x{0438}ei]|and|et)\s+|\x00)/, shift;
}

sub _translate_person ($$$);
sub _translate_person ($$$) {
  my ($self, $aa, $with_year) = (shift, shift, shift);
  my $fail = ($with_year & 2);
  $with_year &= 1;
  my $ini_a = $aa;
  $aa = $aa->[0] if ref $aa;		# [value, handler]
  $aa =~ s/\s+$//;
  # Try early fixing:
  my $a1 = translate_tr $aa;
  return ref $ini_a ? [$a1, $ini_a->[1]] : $a1 if $a1 and $with_year;
  my ($a, @date) = strip_years($aa);
  my $tr_a = translate_tr $a;
  if (not defined $tr_a and $a =~ /(.*?)\s*,\s*(.*)/s) { # Schumann, Robert
    $tr_a = translate_tr "$2 $1";
  }
  if (not defined $tr_a) {
    return if $fail;
    my $ini = $aa;
    # Normalize "translated" to "transl."
    # echo "¯¥à¥¢®¤" | perl -wnle 'BEGIN{binmode STDIN, q(encoding(cp866))}printf qq(\\x{%04x}), ord $_ for split //'
    $aa =~ s/(\s\x{043f}\x{0435}\x{0440})\x{0435}\x{0432}\x{043e}\x{0434}\x{0435}?(\s)/$1.$2/g;
    $aa =~ s/(\s+)\x{0432}\s+(?=\x{043f}\x{0435}\x{0440}\.)/;$1/g; # v per. ==> , per.
    $aa =~ s/[,;.]\s+(\x{043f}\x{0435}\x{0440}\.)\s*/; $1 /g; # normalize space, punct
    $aa =~ s/\b(transl)ated\b/$1./g;

    my @parts = __split_person $aa;
    if (@parts <= 1) {		# At least normalize spacing:
      # Add dots after initials
      $aa =~ s/\b(\w)\s+(?=(\w))/
	       ($1 ne lc $1 and $2 ne lc $2) ? "$1." : "$1 " /eg;
      # Separate initials by spaces unless in a group of initials
      $aa =~ s/\b(\w\.)(?!$|[-\s]|\w\.)/$1 /g;
      return ref $ini_a ? [$aa, $ini_a->[1]] : $aa;
    }
    for my $i (0..$#parts) {
      next if $i % 2;		# Separator
      my $val = _translate_person($self, $parts[$i], $with_year | 2); # fail
      # Deal with cases (currently, in Russian only, after "transl.")
      if (not defined $val and $i
	  and $parts[$i-1] =~ /^;\s+\x{043f}\x{0435}\x{0440}\.\s+$/ # per
	  and $parts[$i] =~ /(.*)\x{0430}$/s) {
	$val = _translate_person($self, "$1", $with_year | 2); # fail
      }
      $val ||= _translate_person($self, $parts[$i], $with_year); # cosmetic too
      $parts[$i] = $val if defined $val;
    }
    $tr_a = join '', @parts;
    return $ini_a if $tr_a eq $ini;
    @date = ();			# Already taken into account...
  }
  my ($short, @date_r) = strip_years($tr_a); # Real date
  @date = strip_duplicate_dates($date_r[0], @date) if @date_r == 1 and @date;
  $tr_a = $short unless $with_year;
  $a = join ' ', $tr_a, @date;
  return ref $ini_a ? [$a, $ini_a->[1]] : $a;
}

sub translate_person ($$) {
  return _translate_person(shift, shift, 1);
}

for my $field (qw(artist artist_collection)) {
  no strict 'refs';
  *{"translate_$field"} = \&translate_person;
}

sub short_person ($$);
sub short_person ($$) {
  my ($self, $a) = (shift, shift);
  my $ini_a = $a;
  $a = $a->[0] if ref $a;		# [value, handler]
  $a = _translate_person($self, $a, 0); # Normalize, no dates of life
  $a =~ s/\s+$//;
  ($a, my @date) = strip_years($a);
  my @parts;
  if (exists $short{$a}) {
    $a = $short{$a};
  } elsif (@parts = __split_person $a and @parts > 1) {
    for my $i (0..$#parts) {
      next if $i % 2;		# Separator
      $parts[$i] = short_person($self, $parts[$i]);
    }
    $a = join '', @parts;
  } else {
    # Drop years of life
    shift @date if @date and $date[0] =~ /^\(\d{4}-[-\d,]*\d{4,}[-\d,]*\)$/;
    # Add dots after initials
    $a =~ s/\b(\w)\s+(?=(\w))/
            ($1 ne lc $1 and $2 ne lc $2) ? "$1." : "$1 " /eg;
    # Separate initials by spaces unless in a group of initials
    $a =~ s/\b(\w\.)(?!$|[-\s]|\w\.)/$1 /g;
    my @a = split /\s+/, $a;
    # Skip shorting if there are strange non upcased parts (e.g., "-") or '()')
    my @check = @a;
    my $von = (@a > 2 and $a[-2] =~ /^[a-z]+$/);
    splice @check, $#a - 1, 1 if $von;
    # Ignore mid parts (skip if there are non upcased parts (e.g., "-") or '()')
    unless (grep lc eq $_, @check or @a <= 1 or $a =~ /\(|[,;]\s/) {
      my $i = substr($a[0], 0, 1);
      $a[0] =  "$i." if $a[0] =~ /^\w\w/ and lc($i) ne $i;
      # Keep "from" in L. van Beethoven, M. di Falla, I. von Held, J. du Pre
      @a = @a[0,($von ? -2 : ()),-1];
    }
    $a = join ' ', @a;
  }
  $a = join ' ', $a, @date;
  return ref $ini_a ? [$a, $ini_a->[1]] : $a;
}

my %comp;

sub normalize_file_lines ($$) {	# Normalizing speeds up load_composer()
  my ($self, $fn) = @_;
  open my $f, '<', $fn or die "Can't open file $fn for read";
  local $_;
  print "# normalized\n";
  while (<$f>) {
    chomp;
    $_ = normalize_piece($self, $_) unless /^\s*#/;
    print "$_\n";
  }
  close $f or die "Can't close file $fn for read";
}

sub _significant ($$$) {
  my ($tbl, $l, $r) = (shift, shift, shift);
  my ($pre, $opus);
  if ($tbl->{no_opus_no}) {	# Remove year-like comment
    ($pre) = ($l =~ /^(.*\S)\s*\(\d{4}\b[^()]*\)$/s);
  } else {
    ($pre, $opus) = ($l =~ /$r/);
  }
  $pre = $l unless $pre;
  my ($significant) = ($pre =~ /^(.*?\bNo[.]?\s*\d+)/is);
  ($significant) = ($pre =~ /^(.*?);/s) unless $significant;
  ($significant) = $pre unless $significant;
  (lc $significant, $opus);
}

sub load_composer ($$) {
  my ($self, $c) = @_;
  eval {$c = $self->shorten_person($c)};
  my $ini = $c;
  return $comp{$ini} if exists $comp{$ini};
  $c =~ s/[^-\w]/_/g;
  $c =~ s/__/_/g;
  # XXX See Wikipedia "Opus number" for more compilete logic
  $comp{$ini}{opus_rx} = qr/\b(?:Op\.|WoO)\s*\d+[a-d]?(?:[.,;\s]\s*No\.\s*\d+(?:\.\d+)*)?/;
  my $f = $INC{'Music_Translate_Fields.pm'};
  warn("panic: can't find myself"), return 0 unless -r $f;
  $f =~ s/\.pm$/-$c.comp/i
    or warn("panic: can't translate `$f' to -$c.comp"), return 0;
  return $comp{$ini} unless -r $f;
  my $tbl = $comp{$ini};
  my (@works, $normalized);
  open COMP, "< $f" or die "Can't read $f: $!";
  my $last;
  my %short;
  for my $l (<COMP>) {
    next if $l =~ /^\s*(?:##|$)/;
    if ($l =~ /^#\s*normalized\s*$/) {
      $normalized++;		# Very significant optimization
    } elsif ($l =~ /^#\s*opus_rex\s(.*?)\s*$/) {
      $tbl->{opus_rx} = qr/$1/;
    } elsif ($l =~ /^#\s*dup_opus_rex\s(.*?)\s*$/) {
      $tbl->{dup_opus_rx} = qr/$1/;
    } elsif ($l =~ /^#\s*no_opus_no\s*$/) {
      $tbl->{no_opus_no} = 1;
    } elsif ($l =~ /^#\s*prev_short\s+(.*?)\s*$/) {
      $short{$1} = $last;
    } elsif ($l =~ /^#[^#]/) {
      warn "Unrecognized line of `$f': $l"
    } elsif ($l !~ /^##/) { 	# Recursive call to ourselves...
      if ($normalized) {
	$l =~ s/\s*$//;		# chomp...
      } else {
	$l = normalize_piece($self, $l);
      }
      $last = $l;
      push @works, $l;
    }
  }
  close COMP or die "Error reading $f: $!";
  return unless @works;
  # Piano Trio No. 8 (Arrangement of the Septet; Op. 20)); Op. 38 (1820--1823)
  # so can't m/.*?/
  my $r = qr/^(.*($tbl->{opus_rx}))/s;
  # Name "as in Wikipedia:Naming conventions (pieces of music)"
  my (%opus, %name, %dup, %dupop);
  for my $l (@works) {
    my ($significant, $opus) = _significant($tbl, $l, $r);
    if ($significant and $name{$significant}) {
      $dup{$significant}++;
      warn "Duplicate name `$significant': <$l> <$name{$significant}>"
	if $ENV{MUSIC_DEBUG_TABLE};
    }
    $name{$significant} = $l if $significant;
    $opus or next;
    $opus = lc $opus;
    if ($opus{$opus}) {
      $dupop{$opus}++;
      warn "Duplicate opus number `$opus': <$l> <$opus{$opus}>"
	unless $tbl->{dup_opus_rx} && $opus =~ /$tbl->{dup_opus_rx}/;
    }
    $opus{$opus} = $l;
  }
  delete $name{$_} for keys %dup;
  delete $opus{$_} for keys %dupop;
  for my $s (keys %short) {
    my ($n) = _significant($tbl, $s, $r);
    warn "Duplicate and/or unnecessary short name `$s' for <$short{$s}>"
      if $name{$n};
    $name{$n} = $short{$s};
    $name{"\0$s"} = "\0$n";	# put into values(), see translate_person()
  }
  $tbl->{works} = \@works;
  $tbl->{opus} = \%opus if %opus;
  $tbl->{name} = \%name if %name;
  $tbl;
}

sub translate_signature ($$$$) { # One should be able to override this
  shift;
  join '', @_;
}
$Music_Translate_Fields::translate_signature = \&translate_signature;

my %alteration = (dur => 'major', moll => 'minor');
my %mod = (is => 'sharp', es => 'flat', '#' => 'sharp', b => 'flat');

# XXXX German ==> English (nontrivial): H ==> B, His ==> B sharp, B ==> B flat
# XXXX Do not touch B (??? Check "Klavier" etc to detect German???)
my %key = (H => 'B');

sub normalize_signature ($$$$) {
  my ($self, $key, $mod, $alteration) = @_;
  $alteration ||= ($key =~ /[A-Z]/) ? ' major' : ' minor';
  $alteration = lc $alteration;
  $alteration =~ s/^-?\s*/ /;
  $alteration =~ s/(\w+)/ $alteration{$1} || $1 /e;
  $mod =~ s/^-?\s*/ / if $mod;		# E-flat, Cb
  $mod = lc $mod;
  $mod =~ s/(\w+|#)/ $mod{$1} || $1 /e;
  $key = uc $key;
  $key = $key{$key} || $key;
  &$Music_Translate_Fields::translate_signature($self,$key,$mod,$alteration);
}

# All these should match in
# mp3info2 -D -a beethoven -t "# 28" "/dev/nul"
#  (should give the same results): "wind in C" "tattoo" "WoO 20"
# "sonata in F#" "piano in F#" "op78" "Op. 10-2" "Op. 10, #2" "sonata #22"

sub normalize_piece ($$) {
  my ($self, $n) = (shift, shift);
  my $ini_n = $n;
  $n = $n->[0] if ref $n;		# [value, handler]
  return $ini_n unless $n;
  $n =~ s/^\s+//;
  $n =~ s/\s+$//;
  return $ini_n unless $n;
  $n =~ s/\s{2,}/ /g;
  $n =~ s/\bOp(us\s+(?=\d)|[.\s]\s*|\.?(?=\d))/Op. /gi;	# XXXX posth.???
  $n =~ s/\bN(?:[or]|(?=\d))\.?\s*(?=\d)/No. /gi; # nr12 n12
  $n =~ s/(\W|^)[#\x{2116}]\s*(?=\d)/${1}No. /gi;	# #12, Numero Sign 12
  # XXXX Is this `?' for good?
  $n =~ s/(?<=[^(])[.,;]?\s*(Op\.|WoO\b)/; $1/gi; # punctuation before Op.
  # punctuation between Op. and No (as in Wikipedia for most expanded listing)
  $n =~ s/\b((Op\.|WoO)\s+\d+[a-d]?)(?:[,;.]?|\s)\s*(?=No\.\s*\d+)/$1, /gi;
  # Tricky part: normalize "In b#"
  $n =~ s/\bin\s+([a-h])(\s*[b#]|(?:\s+|-)(?:flat|sharp)|[ie]s|)((?:(?:\s+|-)(?:major|minor|dur|moll))?)(?=\s*[;"]|$)/
    "in " . normalize_signature($self,$1,$2,$3)/ie;
  my $c = eval {$self->composer} || $self->artist;
  my $canon;
  {
    my $tbl = ($c and load_composer($self, $c));
    $tbl or last;
    # Convert Op. 23-3 to Op. and No
    my ($o, $no) = ($n =~ /\b(Op\.\s+\d+[a-d]?[-\/]\d+[a-d]?)((?:[,;.]?|\s)\s*(?:No\.\s*\d+))?/);
    $n =~ s/\b(Op\.\s+\d+[a-d]?)[-\/](\d+[a-d]?)/$1, No. $2/i
      if $o and not $no and $o !~ /^$tbl->{opus_rx}$/;
    $tbl->{works} or last;
    # XXX See Wikipedia "Opus number" for more complete logic
    my ($opus) = ($n =~ /($tbl->{opus_rx})/);
    if ($opus) {
      $canon = $tbl->{opus}{lc $opus} or last;
    } else {
      my ($significant, $pre, $no, $post) =
	($n =~ /^((.*?)\bNo\b[.]?\s*(\d+(?:\.\d+)*))\s*(.*)/is);
      ($significant) = ($n =~ /^(.*?);/s) unless $significant;
      $significant ||= $n;
      $canon = $tbl->{name}{lc $significant}; # Try exact match
      if (not $canon) {	# Try harder: partial match
	my ($ton, $rx_pre, $rx_post) = ('') x 3;
	my $nn = $n;
	if ($nn =~ s/\b(in\s+[A-H](?:\s+(?:flat|sharp))?\s+(?:minor|major))\b//) {
	  $ton = $1;
	  ($significant, $pre, $no, $post) = # Redo with $nn
	    ($nn =~ /^((.*?)\bNo\b[.]?\s*(\d+(?:\.\d+)*))\s*(.*)/is);
	  $ton = '.*\b' . (quotemeta $ton) . '\b';
	  ($significant) = ($nn =~ /^(.*?);/s) unless $significant;
	  $significant ||= $nn;
	}
	$pre = $significant unless defined $pre;
	# my @parts2 = split '\W+', $post;
	if ($pre and $pre =~ /\w/) {
	  $rx_pre = '\b' . join('\b.*\b', split /\W+/, $pre) . '\b';
	}
	if ($post and $post =~ /\w/) {
	  $rx_post = '.*' . join '\b.*\b', split /\W+/, $post;
	}
	# warn "<$no> <$n> <$nn> <$ton> <$rx_pre> <$rx_post>";
	$no = '.*\bNo\.\s*' . (quotemeta $no) . '\b(?!\.\d)' if $no;
	last unless "$rx_pre$no$ton$rx_post";
	my $sep = $tbl->{no_opus_no} ? '' : '.*;';
	my $rx = qr/$rx_pre$no$ton$rx_post$sep/is;
	my @matches = grep /$rx/, values %{$tbl->{name}};
	if (@matches == 1) {
	  $canon = $matches[0];
	} elsif (!@matches) {
	  last;
	} else {	# Many matches; check that the shortest is substr
	  my ($l, $s, $diff) = 1e100;
	  $l > length and ($s = $_, $l = length) for @matches;
	  $s eq substr $_, 0, $l or ($diff = 1, last) for @matches;
	  last if $diff;
	  $canon = $s;
	}
	$canon = $tbl->{name}{$canon} if $canon =~ s/^\0//s; # short name
      }
    }
#    if ($canon) {
#      my (%w, %w1);
#      for my $w (split /[-.,;\s]+/, $canon) {
#	$w{lc $w}++;
#      }
#      for my $w (split /[-.,;\s]+/, $n) {
#	$w1{lc $w}++ unless $w{lc $w};
#      }
#      if (%w1) {
#	warn "Unknown words in title: `", join("` '", sort keys %w1), "'"
#	  unless $ENV{MUSIC_TRANSLATE_FIELDS_SKIP_WARNINGS};
#	last
#      }
#    }
    $n = $canon;		# XXXX Simple try (need to compare word-for-word)
  }
  return ref $ini_n ? [$n, $ini_n->[1]] : $n;
}

for my $field (qw(album title title_track)) {
  no strict 'refs';
  *{"translate_$field"} = \&normalize_piece;
}

# perl -Ii:/zax/bin -MMusic_Translate_Fields -wle "BEGIN{binmode $_, ':encoding(cp866)' for \*STDIN, \*STDOUT, \*STDERR}print Music_Translate_Fields->check_persons"
sub check_persons ($) {
  my $self = shift;
  my %seen;
  $seen{$_}++ for values %tr;
  for my $l (keys %seen) {
    my $s = short_person($self, $l);
    my $ll = translate_person($self, $s);
    warn "`$l' => `$s' => `$ll'" unless $ll eq $l;
  }
  %seen = ();
  $seen{$_}++ for values %short;
  for my $s (values %seen) {
    my $l = translate_person($self, $s);
    my $ss = short_person($self, $l);
    warn "`$s' => `$l' => `$ss'" unless $ss eq $s;
  }
}

my %aliases;

my $glob = $INC{'Music_Translate_Fields.pm'};
warn("panic: can't find myself"), return 0 unless -r $glob;
$glob =~ s/\.pm$/*.lst/i
  or warn("panic: can't translate `$glob' to .lst"), return 0;
my @lists = <${glob}>;
warn("panic: can't find name lists in `$glob'"), return 0 unless @lists;

for my $f (@lists) {
 open F, "< $f" or warn("Can't open `$f' for read: $!"), next;
 my @in = <F>;
 close F or warn("Can't close `$f' for read: $!"), next;
 if ($in[0] and $in[0] =~ /^ \s* \# \s* charset \s* = \s* ("?) (\S+) \1 \s* $/ix) {
   my $charset = $2;
   require Encode;
   shift @in;
   $_ = Encode::decode($charset, $_) for @in;
 }
 for (@in) {
  next if /^\s*$/;
  s/^\s+//, s/\s+$//, s/\s+/ /g;
  if (/^ \# \s* (alias|fix|shortname_for) \s+ (.*?) \s* => \s* (.*)/x) {
    if ($1 eq 'alias') {
      $aliases{$2} = [split /\s*,\s*/, $3];
    } elsif ($1 eq 'fix') {
      my ($old, $ok) = ($2, $3);
      $tr{translate_dots $old} = $tr{translate_dots $ok} || $ok;
      #print "translating `",translate_dots $old,"' to `",translate_dots $ok,"'\n";
    } elsif ($1 eq 'shortname_for') {
      my ($long, $short) = ($2, $3);
      $tr{translate_dots $short} = $long;
      ($long) = strip_years($long);
      $short{$long} = $short;
    }
    next;
  }
  if (/^ \# \s* fix_firstname \s+ (.*\s(\S+))$/x) {
    $tr{translate_dots $1} = $tr{translate_dots $2};
    next;
  }
  if (/^ \# \s* keep \s+ (.*?) \s* $/x) {
    $tr{translate_dots $1} = $1;
    next;
  }
  if (/^ \# \s* shortname \s+ (.*?) \s* $/x) {
    my $in = $1;
    my $full = __PACKAGE__->_translate_person($in, 0);
    unless (defined $full and $full ne $in) {
      my @parts = split /\s+/, $in;
      $full = __PACKAGE__->_translate_person($parts[-1], 0);
      warn("Can't find translation for `@parts'"), next
	unless defined $full and $full ne $parts[-1];
      # Add the translation
      my $f = __PACKAGE__->translate_person($parts[-1]);
      $tr{translate_dots $in} = $f;
    }
    $short{$full} = $in;
    ($full) = strip_years($full);
    $short{$full} = $in;
    next;
  }
  next if /^##/;
  warn("Do not understand directive: `$_'"), next if /^#/;
  #warn "Doing `$_'";
  my ($pre, $post) = /^(.*?)\s*(\(.*\))?$/;
  my @f = split ' ', $pre or warn("`$pre' won't split"), die;
  my $last = pop @f;
  my @last = $last;
  (my $ascii = $last) =~
	tr( ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ\x80-\x9F)
	  ( !cLXY|S"Ca<__R~o+23'mP.,1o>...?AAAAAAACEEEEIIIIDNOOOOOx0UUUUYpbaaaaaaaceeeeiiiidnooooo:ouuuuyPy_);
  push @last, $ascii unless $ascii eq $last;
  my $a = $aliases{$last[0]} ? $aliases{$last[0]} : [];
  $a = [$a] unless ref $a;
  push @last, @$a;
  for my $last (@last) {
    my @comp = (@f, $last);
    $tr{"\L@comp"} ||= $_;
    $tr{lc $last} ||= $_;		# Two Bach's
    $tr{"\L$f[0] $last"} ||= $_;
    if (@f) {
      my @ini = map substr($_, 0, 1), @f;
      $tr{"\L$ini[0] $last"} ||= $_;	# One initial
      $tr{"\L@ini $last"} ||= $_;	# All initials
    }
  }
 }
}

#$tr{lc 'Tchaikovsky, Piotyr Ilyich'} = $tr{lc 'Tchaikovsky'};

1;
