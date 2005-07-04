#!/usr/bin/perl -w

use strict;
use MP3::Tag;
use File::Find;
use Getopt::Std 'getopts';
use Cwd;

my %opt = (2 => '%a', n => 1, a => 2, t => 1);
# Level=2 header; Level=1 header (default - dir),
# use duration, year, whole dates, replace @ by %, basename of output files,
# ignore 'author' on level > this in directory tree
# use 'album' for titles with depth above this...
getopts('2:1:TyY@B:a:t:', \%opt);
if ($opt{'@'}) {
  $opt{$_} =~ s/\%/\@/ for keys %opt;
}
my $out_envelop_cdcover = \*STDOUT;
my $out_envelop_text;
if (defined $opt{B}) {
  $opt{B} =~ s,\\,/,g;
  open LIST, "> $opt{B}_list.tex" or die "open `$opt{B}_list.tex' for write: $!";
  select LIST;
  if (-e "$opt{B}_cdcover.tex") {
    warn "Will not overwrite existing file `$opt{B}_cdcover.tex'.\n";
    undef $out_envelop_cdcover;
  } else {
    open CDCOV, "> $opt{B}_cdcover.tex"
      or die "open `$opt{B}_cdcover.tex' for write: $!";
    $out_envelop_cdcover = \*CDCOV;
  }
  if (-e "$opt{B}_text.tex") {
    warn "Will not overwrite existing file `$opt{B}_text.tex'.\n";
  } else {
    open TXT, "> $opt{B}_text.tex"
      or die "open `$opt{B}_text.tex' for write: $!";
    $out_envelop_text = \*TXT;
  }
}

# suppose that the directory structure is author/TIT1/TIT2.mp3 or author/TIT2.mp3
# and TIT1 eq "%l"
my $author = '';
my $TIT1 = '';
my $had_subdir;
my $print_dir;
# $|=1;					# For debugging

sub align_numbers ($) {
  (my $in = shift) =~ s/([\s_]*)(\d+)/ sprintf ' %09d%s', $2, $1 /eg;
  $in;
}

my @comments;
my @performers;
my @level;

# Called with short names; $File::Find::dir is set
sub preprocess_and_sort_with_aligned_numbers {
  push @level, $level[-1]+1;
  my $comment;
  my $performer;
  for my $f (@_) {
    if ($f eq '.content_comment' or $f eq '.top_heading') {
      my $ff = "$File::Find::dir/$f";
      next unless -f $ff;
      local $/;
      local *F;
      open F, "< $ff" or die "open `$ff' failed: $!";
      my $c = <F>;
      $c =~ s/^\s+//;
      $c =~ s/\s+$//;
      if ($f eq '.top_heading') {
	my $lev = 0;
	if (not length $c) {
	  # Use dirname
	  $c = $File::Find::dir;
	  $c =~ s,.*/,,;
	} elsif ($c =~ /^-?\d+$/) {
	  $lev = $c;
	  $c = '';
	}
	$level[-1] = $lev;
      }
      ($f eq '.top_heading' ? $performer : $comment) = $c if length $c;
    }
  }
  $performer = $1, $performer =~ s/_/ /g
    if not defined $performer and $level[-1] == 0
      and $File::Find::dir =~ m,.*/(.+), ;
  push @comments, (defined $comment ? $comment: $comments[-1]);
  push @performers, (defined $performer ? $performer: $performers[-1]);
  sort {align_numbers($a) cmp align_numbers($b) or $a cmp $b} @_;
}

sub unwind_dir {
  pop @comments;
  pop @performers;
  pop @level;
}

sub to_TeX ($) {
  (my $in = shift) =~ s/([&_\$#%])/\\$1/g;
  $in =~ s/\.{3}/\\dots{}/g;
  $in =~ s/\bDvorák\b/Dvo\\v rák/g;
  $in;
}

sub to_duration ($) {
  my $s = shift;
  my $h = int($s/3600);
  $s -= $h*3600;
  my $m = int($s / 60);
  $s -= $m*60;
  return sprintf "%d\\hourmark{}%02d'%02d''", $h, $m, $s if $h;
  return sprintf "%d'%02d''", $m, $s;
}

sub cmp_u ($$) {
  my ($a, $b) = (shift, shift);
  (defined $a) ? (not defined $b or $a cmp $b) : defined $b;
}

# Compare with postponed data, either emit, or postpone
my $previous;
sub print_this_mp3 ($) {
  my $new = shift;

  # Print only if toplevel or one level deep, or if directory1 changed...
#  return if defined $new->{dir1}
#    and not cmp_u $new->{dir1}, $previous->{dir1};
  my $changed;
  for my $p (qw(author title comment)) {	# No year!
    if (cmp_u $new->{$p}, $previous->{$p}) {	# Need to print...
      $changed++;
      last
    }
  }
  $previous->{len} += $new->{len} if not $changed and $new->{len};
  return unless $changed;

  # Once per directory given as argument to the script
  if (defined $print_dir and cmp_u $new->{top}, $previous->{top}) {
    $new->{print_top} = $new->{top};
    undef $print_dir;
  }
  # Author may be ignored in deep directories
  if (cmp_u $new->{author_dir}, $previous->{author_dir}
      and cmp_u $new->{author}, $previous->{author}) {
    $new->{print_author} = $new->{author};
  }

  my $this = $previous;
  #my $this = $new;
  $previous = $new;
  return unless %$this;

  # Once per directory given as argument to the script
  if ($this->{print_top}) {
    print "\n\\preDir ";
    print to_TeX $this->{top};
    print "\\postDir\n";
  }
  if ($this->{print_author}) {
    print "\n\\preauthor ";
    print to_TeX $this->{author};
    print "\\postauthor\n";
  }
  my $comment = '';
  $comment = "\\precomment " . to_TeX($this->{comment}) . "\\postcomment "
    if defined $this->{comment};
  my $year = (defined $this->{year} ? $this->{year} : '');
  if ($opt{T}) {
    my $dur = to_duration $this->{len};
    $dur .= '\postduration ' if length $year;
    $year = "$dur$year"
  }
  $year = "\\preyear $year\\postyear" if length $year;

  print "\\pretitle ";
  print to_TeX $this->{title};
  print "$comment$year\\posttitle\n";
}

# Callback for find():
sub print_mp3 {
  return unless -f $_ and /\.mp3$/i;
  #print STDERR "... $_\n";
  my $tag = MP3::Tag->new($_);
  my @parts = split m<[/\\]>, $File::Find::dir;
  shift @parts if @parts and $parts[0] eq '.';

  my $this;
  $this->{top} = $opt{1} ? $tag->interpolate($opt{1}) : $performers[-1];
  $this->{author} = $tag->interpolate($opt{2});	# default '%a'
  $this->{title} = $tag->interpolate(@parts <= $opt{t} ? '%t' : '%l');
  $this->{len} = $tag->interpolate('%S') if $opt{T};
  my $l_part = $opt{a};
  $l_part = $#parts if $l_part >= $#parts;
  $this->{author_dir} = join '/', @parts[0..$l_part];
  $this->{dir1} = $parts[1];	# Not used anymore...

  $this->{comment} = $comments[-1];

  if ($opt{y}) {
    my $year = $tag->year;
    $year =~ s/(\d)-(?=\d{4})/$1--/g;
    # Contract long dates (with both ',' and '-')
    if ($year and $year =~ /,/ and $year =~ /-/ and not $opt{Y}) {
      $year =~ s/-?(-\d\d?\b)+//g;	# Remove month etc
      1 while $year =~ s/\b(\d{4})(?:,|--)\1/$1/g;	# Remove "the same" year
      (my $y = $year) =~ s/--/,/g;
      # Remove intermediate dates if more than 3 years remain
      $year =~ s/(,|--).*(,|--)/--/ if ($y =~ tr/,//) > 2;
    }
    $this->{year} = $year if length $year;
  }
  print_this_mp3($this);
  return;
}

my $common1 = <<'EOP';
%\pretolerance=-1%	Always hyphenation: always

\def\hourmark#1{$\mathsurround0pt{}^{\scriptscriptstyle\circ}$}
\def\preauthor{\pagebreak[1]\bgroup\centering\bf}
\def\postauthor{\par\egroup}
\def\pretitle{\bgroup}
\def\posttitle{\par\egroup}
\def\precomment{ \bgroup\it}
\def\postcomment{\egroup}
%\def\preyear{ \hfil\hbox{}\hskip0pt\hbox{}\nobreak\hskip0pt plus 1fill\nobreak[}
%%\def\preyear{\unskip\nobreak\hfil\penalty50\hskip0.75em\hbox{}\nobreak\hfill[}
%\def\postyear{]}

\def\postduration{, }

% Sigh...  We want year to be right-aligned, moved to the next row if it
% does not fit into the last row, want it to be not hyphenated if it fits
% into the line, and want it to not change the typesetting of the rest of
% the text (as far as it is possible).

% We need at least two \hfil's since if line break happens, we need to push
% the previous line left, and the year right.  Breaks happen only on the
% left end of leftmost kern/glue or on penalties; so we need \nobreak only
% at the left ends. \null is needed to create a break place between two
% pieces of glue.
% If break happens, \hskip disappears, and we get two \hfil's;
% If it does not happen, we get 0.75em plus 1fil plus 1fill.
% \penalty 80 helps squeezing the line a little bit if year fits into
% the last line, but only tightly (or if an extra hyphenation is required?).

% Finally, an extra line break can make the ending-hyphenation of a paragraph
% to become non-ending; if \finalhyphendemerits is non-0, this makes
% the break performed even if year fits (in the presense of ending-hyphenation
% in the main text).  This \finalhyphendemerits requires groups in \pretitle
% \postttile...

% \linewidth differs from \hsize by \left-\rightmargin's.
\def\preyear#1\postyear{\unskip\nobreak\hfil\penalty 80\hskip0.75em
  \null\nobreak\hfill
  \sbox 0{[#1]}\ifdim \wd 0 > \linewidth [#1]\else    \box 0\fi
  \finalhyphendemerits=0\relax}

% Make this more negative for denser type
\parskip=-1.1pt plus 1.1pt\relax

EOP

my $cdcover_on = <<'EOP';
\begin{bookletsheets}
%\begin{bookletsheetsTwo}
%\begin{singlesheet}{Title}{Slip text}

%\begin{multicols}{4}
EOP

my $common2 = <<'EOP';
% Choose a size which better fits the pages...
%\small
\footnotesize
%\scriptsize
%\tiny

\leftskip=1.3em
\parindent=-\leftskip\relax

EOP

print $out_envelop_cdcover <<'EOP' if defined $out_envelop_cdcover;
%\documentclass[12pt]{article}

\documentclass{cd-cover}
%\documentclass{cd-cover2}
%\usepackage{multicol}

\usepackage[T2A]{fontenc}
\usepackage[latin1]{inputenc}
% cp866 for DosCyrillic, cp1251 for WinCyrillic
%\usepackage[cp866]{inputenc}
%\usepackage[cp1251]{inputenc}
%\usepackage[russian]{babel}

\begin{document}

\def\preDir{\pagebreak[2]\bgroup\centering\bf\normalsize}
\def\postDir{\par\egroup}
\CDbookletMargin=1.5mm
\CDbookletTopMargin=1.5mm
\CDsingleMargin=1.5mm
\CDsingleTopMargin=1.5mm

EOP

print $out_envelop_text <<'EOP' if defined $out_envelop_text;
\documentclass[12pt]{article}
\usepackage[margin=2cm,nohead,nofoot]{geometry}
\usepackage{multicol}

\usepackage[T2A]{fontenc}
\usepackage[latin1]{inputenc}
% cp866 for DosCyrillic, cp1251 for WinCyrillic
%\usepackage[cp866]{inputenc}
%\usepackage[cp1251]{inputenc}
%\usepackage[russian]{babel}

\def\COLUMNS{2}

\begin{document}

\def\SETDIR#1{\bgroup\centering\bf\normalsize#1\par\egroup}
\let\PREDIR\relax
\def\preDir#1\postDir{\PREDIR\relax\def\PREDIR{\end{multicols}}%
		      \begin{multicols}{\COLUMNS}[\SETDIR{#1}]\relax}
\columnsep 9pt
\columnseprule.4pt
\multicolsep 3pt plus 4pt minus 3pt

EOP

for my $out (grep defined, $out_envelop_cdcover, $out_envelop_text) {
  print $out $common1;
  print $out $cdcover_on
    if defined $out_envelop_cdcover and $out eq $out_envelop_cdcover;
  print $out $common2;
  print $out <<"EOP" if defined $opt{B};	# \include has extra \clearpage

\\input{$opt{B}_list}

EOP
}


print $out_envelop_cdcover <<'EOP' if defined $out_envelop_cdcover;
%\end{multicols}
\end{bookletsheets}
%\end{bookletsheetsTwo}
%\end{singlesheet}
\end{document}
EOP

print $out_envelop_text <<'EOP' if defined $out_envelop_text;
\end{multicols}
\end{document}
EOP

close $_ or warn "Error closing wrapper for write: $!"
  for grep defined, $out_envelop_cdcover, $out_envelop_text;

my $d = Cwd::cwd;
for (@ARGV) {
  $had_subdir = 0;
  warn("Not a directory: `$_'"), next unless -d;
  chdir $_ or die "Can't chdir `$_'";
  (my $name = $_) =~ s,.*[/\\](?!$),,;
  $name =~ s/_/ /g;
  $print_dir = $name;
  @level = (0);
  @performers = ($print_dir);
  @comments = (undef);
#  print <<EOP;
#\\preDir $name\\postDir
#EOP
  $author = '';
  $TIT1 = '';
  undef $previous;
  File::Find::find { wanted => \&print_mp3, no_chdir => 1,
		     postprocess => \&unwind_dir,
		     preprocess => \&preprocess_and_sort_with_aligned_numbers },
		'.';
  print_this_mp3({});	# Flush the postponed data
  chdir $d or die;
}
