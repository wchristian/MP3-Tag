package Music_Translate_Fields;
use strict;

my %tr;
my %short;

sub translate_tr ($) {
  my $a = shift;
  $a =~ s/^\s+//;
  $a =~ s/\s+$//;
  $a =~ s/\s+/ /g;
  $a =~ s/\b(\w)\.\s*/$1 /g;
  $a = $tr{lc $a} or return;
  return $a;
}

# Returns $name, $year (second part optional)
sub strip_year ($) {		# Keep a range of dates, strip single dates
  my ($a) = (shift);
  my @rest;
  return $a unless		# RANGE DATES+ (keep RANGE) or DATES+
    $a =~ s/(\(\d{4}(?=[-\d,]*-(?:-|\d{4}))[-\d]+\))((?:\s+\([-\d,]+\))+)$/$1/
      or $a =~ s/((?:\s+\([-\d,]+\))+)$//;
  @rest = $+;
  $rest[0] =~ s/^\s+//;
  return $a, @rest;
}

sub translate_artist ($$) {
  my ($self, $a) = (shift, shift);
  my $ini_a = $a;
  $a = $a->[0] if ref $a;		# [value, handler]
  $a =~ s/\s+$//;
  ($a, my @date) = strip_year($a);
  my $tr_a = translate_tr $a;
  if (not $tr_a and $a =~ /(.*?)\s*,\s*(.*)/s) {	# Schumann, Robert
    $tr_a = translate_tr "$2 $1";
  }
  $a = $tr_a or return $ini_a;
  $a = join ' ', $a, @date;
  return ref $ini_a ? [$a, $ini_a->[1]] : $a;
}

*translate_person = \&translate_artist;

sub short_person ($$) {
  my ($self, $a) = (shift, shift);
  my $ini_a = $a;
  $a = translate_person($self, $a); # Normalize
  $a = $a->[0] if ref $a;		# [value, handler]
  $a =~ s/\s+$//;
  ($a, my @date) = strip_year($a);
  if (exists $short{$a}) {
    $a = $short{$a};
  } else {
    # Drop years of life
    $a =~ s/(?:\s+\([-\d,]{4,}\))*$//;
    # Separate initials by spaces unless in a group of initials
    $a =~ s/\b(\w\.)(?!$|[-\s]|\w\.)/$1 /g;
    my @a = split /\s+/, $a;
    # Skip if there are non upcased parts (e.g., "-") or '()'
    unless (grep lc eq $_, @a or @a <= 1 or $a =~ /\(/) {
      my $i = substr($a[0], 0, 1);
      $a[0] =  "$i." if $a[0] =~ /^\w\w/ and lc($i) ne $i;
      @a = @a[0,-1];
    }
    $a = join ' ', @a;
  }
  $a = join ' ', $a, @date;
  return ref $ini_a ? [$a, $ini_a->[1]] : $a;
}

sub translate_name ($$) {
  my ($self, $n) = (shift, shift);
  my $ini_n = $n;
  $n = $n->[0] if ref $n;		# [value, handler]
  $n =~ s/\bOp([.\s]\s*|.?(?=\d))/Op. /gi;
  $n =~ s/\bN[or]([.\s]\s*|.?(?=\d))/No. /gi;	# nr12
  $n =~ s/(\W)#\s*(?=\d)/${1}No. /gi;	# #12
  $n =~ s/[.,;]\s*Op\./; Op./gi;	# #12
  return ref $ini_n ? [$n, $ini_n->[1]] : $n;
}

*translate_album = \&translate_name;
*translate_title = \&translate_name;

my %aliases;

my $glob = $INC{'Music_Translate_Fields.pm'};
warn("panic: can't find myself"), return 0 unless -r $glob;
$glob =~ s/\.pm$/*.lst/i
  or warn("panic: can't translate `$glob' to .txt"), return 0;
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
  if (/^ \# \s* (alias|fix) \s+ (.*?) \s* => \s* (.*)/x) {
    if ($1 eq 'alias') {
      $aliases{$2} = [split /\s*,\s*/, $3];
    } elsif ($1 eq 'fix') {
      $tr{lc $2}	 = $tr{lc $3};
    }
    next;
  }
  if (/^ \# \s* fix_firstname \s+ (.*\s(\S+))$/x) {
    $tr{lc $1} = $tr{lc $2};
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
	tr( ¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏĞÑÒÓÔÕÖ×ØÙÚÛÜİŞßàáâãäåæçèéêëìíîïğñòóôõö÷øùúûüışÿ\x80-\x9F)
	  ( !cLXY|S"Ca<__R~o+23'mP.,1o>...?AAAAAAACEEEEIIIIDNOOOOOx0UUUUYpbaaaaaaaceeeeiiiidnooooo:ouuuuyPy_);
  push @last, $ascii unless $ascii eq $last;
  my $a = $aliases{$last[0]} ? $aliases{$last[0]} : [];
  $a = [$a] unless ref $a;
  push @last, @$a;
  for my $last (@last) {
    my @comp = (@f, $last);
    $tr{"\L@comp"} = $_;
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
