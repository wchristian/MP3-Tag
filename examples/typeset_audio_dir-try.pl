#!/usr/bin/perl -w

$VERSION = 0.03;

use strict;
use MP3::Tag;
use File::Find;
use Getopt::Std 'getopts';
use Cwd;

my %iniopt = (2 => '%a', a => 2, t => 1, S => '');
my %opt = %iniopt;
# Level=2 header; Level=1 header (default - dir),
# use duration, year, whole dates, replace @ by %, basename of output files,
# ignore 'author' on level > this in directory tree
# use 'album' for titles with depth above this..., encodings, no comment,
# lyrics, style
my @args = @ARGV;

sub my_getopts {
  getopts('2:1:TyYn@B:a:t:e:cLS:', \%opt);
}
sub my_regetopts ($) {
  my $style = shift;
  %opt = (%iniopt, %$style);
  @ARGV = @args;
  my_getopts;
}

my_getopts;

  # Use artist as toplevel heading, album as the 2nd level; use track numbers;
  # name is based on title for any depth in directory hierarchy;
  # likewise for generation of 2nd level heading.  Mark pieces with lyrics
##  typeset_audio_dir -@ -ynTL -1 "@a" -2 "@l" -t 1000 -a 1000 -B All .

  # Likewise, but the name is based on the album; ignore comments
##  typeset_audio_dir    -yTn -1 "" -2 ""  -c -t -1e100 -a -1e100 -B All_sh .

my %styles = ( long  => { 1 => '%a', 2 => '%l', t => 1e100,  a => 1e100},
	       short => { 1 => '',   2 => '',   t => -1e100, a => -1e100},
	     );
my $opt_long;
if ($opt{S} eq 'both') {
  my_regetopts($styles{long});
  $opt_long = {%opt, no_time => 1};
  my_regetopts($styles{short});
} elsif ($opt{S}) {
  my $h = $styles{$opt{S}};
  die "Unknown style `$opt{S}'" unless $h;
  my_regetopts($h);
}

if ($opt{'@'}) {
  $opt{$_} =~ s/\@/\%/g for keys %opt;
}
my %enc;
if ($opt{e}) {	# Comma-separated, each 'encoding' or '[d][h][o]:encoding'
  for my $e (split /,/, $opt{e}) {
    # o=output, d=dirname, h=.hintfiles
    $enc{o} = $enc{d} = $enc{h} = $e, next unless $e =~ /:/;
    my($what, $enc) = split /:/, $e, 2;
    for my $w (split //, $what) {
      $enc{$w} = $enc;
    }
  }
}
my $out_envelop_cdcover = \*STDOUT;
my $out_envelop_text;
my $out_envelop_backcover;
my $out_envelop_12cm;
my $out_list = \*STDOUT;
my $out_list_long;
die "option `-S both' requires -B" if not $opt{B} and $opt{S} eq 'both';

if (defined $opt{B}) {
  $opt{B} =~ s,\\,/,g;
  open LIST, "> $opt{B}_list.tex" or die "open `$opt{B}_list.tex' for write: $!";
  select LIST;
  $out_list = \*LIST;
  if ($opt{S} eq 'both') {
    open LLIST, "> $opt{B}_list_long.tex" or die "open `$opt{B}_list_long.tex' for write: $!";
    $out_list_long = \*LLIST;
  }
  if (-e "$opt{B}_cdcover.tex") {
    warn "Will not overwrite existing file `$opt{B}_cdcover.tex'.\n";
    undef $out_envelop_cdcover;
  } else {
    open CDCOV, "> $opt{B}_cdcover.tex"
      or die "open `$opt{B}_cdcover.tex' for write: $!";
    $out_envelop_cdcover = \*CDCOV;
  }
  if (-e "$opt{B}_backcover.tex") {
    warn "Will not overwrite existing file `$opt{B}_backcover.tex'.\n";
  } else {
    open BACKCOV, "> $opt{B}_backcover.tex"
      or die "open `$opt{B}_backcover.tex' for write: $!";
    $out_envelop_backcover = \*BACKCOV;
  }
  if (-e "$opt{B}_text.tex") {
    warn "Will not overwrite existing file `$opt{B}_text.tex'.\n";
  } else {
    open TXT, "> $opt{B}_text.tex"
      or die "open `$opt{B}_text.tex' for write: $!";
    $out_envelop_text = \*TXT;
  }
  if (-e "$opt{B}_cdbooklet.tex") {
    warn "Will not overwrite existing file `$opt{B}_cdbooklet.tex'.\n";
  } else {
    open _12CM, "> $opt{B}_cdbooklet.tex"
      or die "open `$opt{B}_cdbooklet.tex' for write: $!";
    $out_envelop_12cm = \*_12CM;
  }
}
if ($enc{o}) {
  eval {binmode $out_list, ":encoding($enc{o})"} or warn $@;
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
      next unless -f $ff;	# ignore non-files
      local $/;
      local *F;
      open F, "< $ff" or die "open `$ff' failed: $!";
      my $c = <F>;
      if ($enc{h}) {
	eval {
	  require Encode;
          $c = Encode::decode($enc{h}, $c);
	} or warn $@;
      }
      $c =~ s/^\s+//;
      $c =~ s/\s+$//;
      if ($f eq '.top_heading') {
	my $lev = 0;
	if (not length $c) {
	  $lev = -1;
	} elsif ($c =~ /^-?\d+$/) {
	  $lev = $c - 1;
	  $c = '';
	}
	$level[-1] = $lev;
      }
      ($f eq '.top_heading' ? $performer : $comment) = $c if length $c;
    }
  }
  if (not defined $performer and $level[-1] == 0
      and $File::Find::dir =~ m,.*/(.+), ) {
    $performer = $1;
    if ($enc{d}) {
      eval {
        require Encode;
        $performer = Encode::decode($enc{h}, $performer);
      } or warn $@;
    }
    $performer =~ s/_/ /g;
  }
  push @comments, (defined $comment ? $comment: $comments[-1]);
  push @performers, (defined $performer ? $performer: $performers[-1]);
  sort {align_numbers($a) cmp align_numbers($b) or $a cmp $b} @_;
}

sub unwind_dir {
  $print_dir = 1 if $level[-1] == 0; # Need to print again
  pop @comments;
  pop @performers;
  pop @level;
}

sub to_TeX ($) {
  # Assume high-bit characters are letters
  (my $in = shift) =~ s/([&_\$#%~])/\\$1/g;
  $in =~ s/(\b|(?<=\.\.\.)|(?<=[\x80-\xFF]))`\B|`$/'/g;
  $in =~ s/\B'(\b|(?=[\x80-\xFF]))|^'/`/g;
  $in =~ s/(\b|(?<=\.\.\.)|(?<=[\x80-\xFF]))"\B|"$/''/g;
  $in =~ s/\B"(\b|(?=[\x80-\xFF]))|^"/``/g;
  $in =~ s/\.{3}/\\dots{}/g;
  $in =~ s/\s+-\s+/---/g;
  $in =~ s/(?<=\b[[:upper:]]\.)\s+(?=[[:upper:]])/~/g;
  $in =~ s/\bDvor�k\b/Dvo\\v r�k/g;
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
my $total_sec = 0;

# Compare with postponed data, either emit, or postpone
my $previous;
my $previous_long;
sub print_this_mp3 ($$$) {
  my ($new, $opt, $previous) = (shift, shift, shift);

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

  # Once per toplevel directory
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
  if (defined $this->{print_top}) {
    print "\n\\preDir ";
    print to_TeX $this->{print_top};
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
  $year .= '\hasSyncLyrics' if $this->{syncLyr};
  $year .= '\hasUnsyncLyrics' if $this->{unsyncLyr};
  if ($opt->{T}) {
    $total_sec += $this->{len} unless $opt->{no_time};
    my $dur = to_duration $this->{len};
    $dur .= '\postduration ' if length $year;
    $year = "$dur$year"
  }
  $year = "\\preyear $year\\postyear" if length $year;

  print "\\pretitle ";
  if ($this->{track}) {		# Do not typeset 0 or empty
    print "\\pretrack ";
    print to_TeX $this->{track};
    print "\\posttrack ";
  }
  print to_TeX $this->{title};
  print "$comment$year\\posttitle\n";
}

sub print_mp3_via_tag ($$$) {
  return unless -f $_ and /\.mp3$/i;
  #print STDERR "... $_\n";
  my ($tag, $opt, $previous) = (shift, shift, shift);
  my @parts = split m<[/\\]>, $File::Find::dir;
  shift @parts if @parts and $parts[0] eq '.';

  my $this;
  $this->{top} = $opt->{1} ? $tag->interpolate($opt->{1}) : $performers[-1];
  $this->{author} = $tag->interpolate($opt->{2});	# default '%a'
  $this->{title} = $tag->interpolate(@parts <= $opt->{t} ? '%t' : '%l');
  $this->{track} = $tag->track if $opt->{n} and @parts <= $opt->{t};
  $this->{len} = $tag->interpolate('%S') if $opt->{T};
  my $l_part = $opt->{a};
  $l_part = $#parts if $l_part >= $#parts;
  $this->{author_dir} = join '/', @parts[0..$l_part];
  $this->{dir1} = $parts[1];	# Not used anymore...

  my $c = !$opt->{c}
    && $tag->select_id3v2_frame_by_descr('TXXX[add-to:file-by-person,l,t,n]');
  $this->{comment} = (defined $c and length $c) ? "($c)" : $comments[-1];

  if ($opt->{y}) {
    my $year = $tag->year;
    $year =~ s/(\d)-(?=\d{4})/$1--/g;
    # Contract long dates (with both ',' and '-')
    if ($year and $year =~ /,/ and $year =~ /-/ and not $opt->{Y}) {
      $year =~ s/-?(-\d\d?\b)+//g;	# Remove month etc
      1 while $year =~ s/\b(\d{4})(?:,|--)\1/$1/g;	# Remove "the same" year
      (my $y = $year) =~ s/--/,/g;
      # Remove intermediate dates if more than 3 years remain
      $year =~ s/(,|--).*(,|--)/--/ if ($y =~ tr/,//) > 2;
    }
    $this->{year} = $year if length $year;
  }
  if ($opt->{L}) {
    $this->{syncLyr} = $tag->have_id3v2_frame('SYLT');
    $this->{unsyncLyr} = $tag->have_id3v2_frame('USLT');
  }
  print_this_mp3($this, $opt, $previous);
  return;
}

# Callback for find():
sub print_mp3 {
  return unless -f $_ and /\.mp3$/i;
  #print STDERR "... $_\n";
  my $tag = MP3::Tag->new($_);
  if ($out_list_long) {
    my $out = select;
    select $out_list_long;
    print_mp3_via_tag($tag, $opt_long, $previous_long);
    select $out;
  }
  print_mp3_via_tag($tag, \%opt, $previous);
}

my $oenc = $enc{o} || 'utf8';
my $common_enc = <<'EOP';

\usepackage[T2A]{fontenc}
EOP

$common_enc .= <<EOP;
\\usepackage[$oenc]{inputenc}
EOP

$common_enc .= <<'EOP';
%\usepackage[utf8]{inputenc}
%\usepackage[latin1]{inputenc}
% cp866 for DosCyrillic, cp1251 for WinCyrillic
%\usepackage[cp866]{inputenc}
%\usepackage[cp1251]{inputenc}
%\usepackage[russian]{babel}

\usepackage{textcomp}		% More Unicode symbols

EOP

my $common1 = <<'EOP';
%\pretolerance=-1%	Always hyphenation: always

\def\hourmark#1{$\mathsurround0pt{}^{\scriptscriptstyle\circ}$}
\newdimen\PREauthorSKIP
\newdimen\POSTauthorSKIP
\PREauthorSKIP 0pt\relax
\POSTauthorSKIP 0pt\relax
\def\preauthor{\pagebreak[1]\addvspace{\PREauthorSKIP}\bgroup\centering\bf}
\def\postauthor{\par\egroup\addvspace{\POSTauthorSKIP}}
\def\pretitle{\bgroup}
\def\posttitle{\par\egroup}
\def\precomment{ \bgroup\it}
\def\postcomment{\egroup}
\def\pretrack#1\posttrack{#1.\hbox{~}}	% Not expandable
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

\def\addOnRight#1{%
  \unskip\nobreak\hfil\penalty 80\hskip0.75em\null\nobreak\hfill
  \sbox 0{#1}\ifdim \wd 0 > \linewidth #1\else    \box 0\fi
  \finalhyphendemerits=0\relax
}

% \linewidth differs from \hsize by \left-\rightmargin's.
\def\preyear#1\postyear{\addOnRight{[#1]}}

% Make this more negative for denser type
\parskip=-1.1pt plus 1.1pt\relax

EOP

if ($opt{L}) {
  $common1 .= <<'EOP';

\def\hasUnsyncLyrics{\textcircled{\textsc{L}}}
\def\hasSyncLyrics{\textcircled{\textsc{S}}}
\def\reportLyricsSyntax{{\tiny\hasUnsyncLyrics/\hasSyncLyrics\quad---\quad
  has (un)syncronized lyrics\par}}
EOP
} else {
  $common1 .= <<'EOP';

\def\reportLyricsSyntax{}
EOP
}

my $cdcover_on = <<'EOP';
\begin{bookletsheets}
%\begin{bookletsheetsTwo}
%\begin{singlesheet}{Title}{Slip text}

%\begin{multicols}{4}
EOP

my $backcover_on = <<'EOP';
%\begin{bookletsheets}
%\begin{bookletsheetsTwo}
%\begin{singlesheet}{Title}{Slip text}

%%% Replace by backsheet* to get other direction of spines
%\begin{backsheet}{% Set up title (possibly multiline)
\begin{backcover-ml}{%
{\bf Put your TITLE here}\tiny
and add some content
\addOnRight{\bf \today}%
}

\begin{multicols}{\COLUMNS}
EOP

my $base = defined $opt{B}? $opt{B} : '';	# Avoid warning
my $envelop_12cm_on = <<EOP;
%\\footnotesize
%\\begin{center}
%\\input{${base}_title}
%\\end{center}

\\vskip 3pt
\\hrule height1.7pt\\relax
\\vskip 1.2pt
\\hrule height0.8pt\\relax
\\vskip 3pt

EOP



sub common2 ($) {
  my $which = shift;
  (my $common2 = <<'EOP') =~ s/^%(\\\Q$which\E)\b/$1/m or die $which; # Uncomment $which
% Choose a size which better fits the pages...
%\small
%\footnotesize
%\scriptsize
%\tiny

\leftskip=1.3em
\parindent=-\leftskip\relax

EOP
  $common2;
}

print $out_envelop_cdcover <<'EOP' if defined $out_envelop_cdcover;
%\documentclass[12pt]{article}

\documentclass{cd-cover}
%\documentclass{cd-cover2}
%\usepackage{multicol}
EOP

my $cdcover_set = <<'EOP';	# XXXX \small for backcover?

\begin{document}

\def\preDir{\pagebreak[2]\bgroup\centering\bf\normalsize}
\def\postDir{\par\egroup}
\CDbookletMargin=1.5mm
\CDbookletTopMargin=1.5mm
\CDsingleMargin=1.5mm
\CDsingleTopMargin=1.5mm
\CDbackMargin=1.5mm
\CDbackTopMargin=1.5mm

EOP

print $out_envelop_cdcover $common_enc, $cdcover_set
  if defined $out_envelop_cdcover;

print $out_envelop_backcover <<'EOP' if defined $out_envelop_backcover;
%\documentclass[12pt]{article}

\documentclass{cd-cover}
\newenvironment{backcover-ml}[1]{% `backsheet' puts multiline spines
				 % in a wrong place....
  \backsheet{{% Set up title (possibly multiline)
    \setlength\unitlength{1mm}%
    \begin{picture}(0,0)
      %% There MUST be an easier way to put mid-of-left-edge of a block at pos
      \put(0.5,2.5){\makebox(0,0)[bl]{%
	\raisebox{-0.5\height}[0pt][0pt]{%
	  \begin{minipage}[b]{11.7cm}%
	    %%% This will create really tight multi-line:
	    \lineskiplimit=10cm\lineskip=-0.5pt minus 1pt\relax
  #1%
	  \end{minipage}%
	}%
      }}
    \end{picture}
  }}%
}{\endbacksheet}

\usepackage{multicol}

\def\COLUMNS{3}
EOP

my $set_columns = <<'EOP';
\columnsep 9pt
\columnseprule.4pt
%\multicolsep 3pt plus 4pt minus 3pt
% Need to put adjacent horizontal lines, so this is better:
\multicolsep 0pt
\newlength\Multicolsep		% Insert manually
% Dynamically change:
\def\myMulticolsep{\setlength{\Multicolsep}{0.7ex plus 0.9ex minus 0.7ex}%
  \addvspace\Multicolsep}

EOP

$cdcover_set =~ s/\\normalsize\b/\\small/;
print $out_envelop_backcover $set_columns, $common_enc, $cdcover_set
  if defined $out_envelop_backcover;

print $out_envelop_12cm <<'EOP' if defined $out_envelop_12cm;
% Postprocess this file with something like
%   dvips -t landscape -f < This_File.dvi | psbook | pstops "2:0(0,6cm)+1(0,-6cm)" > Output.ps
% Some (broken) printers require finer tuning of file positions
% for correct duplex.  E.g., to move the text 1.4mm to the left,
%   dvips -t landscape -f < This_File.dvi | psbook | pstops "2:0(0,6.14cm)+1(0,-5.86cm)" > Output.ps
% With some versions (of graphics.cfg?) one needs to invert the offsets:
%   dvips -t landscape -f < This_File.dvi | psbook | pstops "2:0(0,-6cm)+1(0,6cm)" > Output.ps
%   dvips -t landscape -f < This_File.dvi | psbook | pstops "2:0(0,-5.86cm)+1(0,6.14cm)" > Output.ps

\documentclass{article}

% Use 2mm margin inside 12cm x 12cm page; page numbers fit only accidentally...
\usepackage[centering,landscape,width=11.6truecm,height=11.6truecm,nohead,nofoot]{geometry}

\usepackage{multicol}

\def\COLUMNS{2}

EOP

print $out_envelop_12cm $set_columns, $common_enc if defined $out_envelop_12cm;
print $out_envelop_12cm <<'EOP' if defined $out_envelop_12cm;

% This page style adds a frame about the text area
\makeatletter
\def\ps@framed{%	Add frame to current ornaments
     \def\ps@framed@head{{%		Localize
	\setlength\unitlength{1sp}%	So that \number works OK
	\linethickness{0.2pt}%
	% Text may actually go below \textheight - it gives the baseline...
	%\advance\textheight\maxdepth	% It is localized anyway...
	% Use this as a temporary register
	\maxdepth=2truemm\relax
	% Increase box size by 4mm
	\advance\headsep -\maxdepth
	\advance\textwidth \maxdepth
	\advance\textwidth \maxdepth
	\advance\textheight \maxdepth
	\advance\textheight \maxdepth
	\begin{picture}(0,0)%
	% This is put at bottom of heading, so \headheight is above us
	  \put(-\number\maxdepth,-\number\headsep){%
		\begin{picture}(0,0)%
		  \put(0,-\number\textheight){%
		    \framebox(\number\textwidth,\number\textheight){}}%
		\end{picture}}%
	\end{picture}%
     }}%
     \let\ps@framed@oddhead\@oddhead
     \let\ps@framed@evenhead\@evenhead
     \def\@oddhead{\ps@framed@head\ps@framed@oddhead}%
     \def\@evenhead{\ps@framed@head\ps@framed@evenhead}}
\makeatother

EOP

my $set_headers = <<'EOP';
\begin{document}

\pagestyle{framed}

% \multicolsep + \extraSomething: \small => 1.2pt; \scriptsize => -1.4pt

% These hardcoded 3pt, 4pt values are very questionable...
% Work with footnotesize (ex=4.6pt);
% with scriptsize (ex=3.2pt) one needs 1.5pt instead of 3pt...
% The trick below: (1ex-1.5pt)
% does not work with tiny (ex=2.2pt) by about 1.5pt; but if one corrects,
% the line touches the header...

% The calculations done by multicol are too complicated to grasp.
% But they are effectively disabled by \nointerlineskip
\def\SETDIR#1{\bgroup\centering\bf\dirSIZE#1\par\egroup
	      \myMulticolsep\hrule
	      \vbox to 0pt{}\relax\nointerlineskip}
\def\preDIR{\end{multicols}%
   \hrule\vskip 4pt\relax}
\def\preDIR{\end{multicols}%	% XXXX Why 0.5ex is needed???
   \nointerlineskip\vbox to 0.5ex{}\relax\hrule\myMulticolsep}
\def\PREDIRi{\let\PREDIR\preDIR}
\let\PREDIR\PREDIRi			% Do nothing on the first invocation

\def\preDir#1\postDir{\PREDIR\begin{multicols}{\COLUMNS}[\SETDIR{#1}]\relax}
\def\dirSIZE{\normalsize}

EOP

print $out_envelop_12cm $set_headers if defined $out_envelop_12cm;
$set_headers =~ s/^(\\pagestyle\{.*})\s*//m or die;

print $out_envelop_text <<'EOP' if defined $out_envelop_text;
\documentclass[12pt]{article}
\usepackage[margin=2cm,nohead,nofoot]{geometry}
\usepackage{multicol}

EOP

print $out_envelop_text $set_columns, $common_enc if defined $out_envelop_text;
print $out_envelop_text <<'EOP' if defined $out_envelop_text;

\def\COLUMNS{2}

EOP

$set_headers =~ s/^(\\pagestyle\{.*})\b//m;
print $out_envelop_text $set_headers if defined $out_envelop_text;

for my $o (grep defined $_->[0],
	   [$out_envelop_backcover, 'tiny'],
	   [$out_envelop_cdcover, 'scriptsize'],
	   [$out_envelop_text, 'footnotesize'],
	   [$out_envelop_12cm, 'scriptsize']) {
  my $out = $o->[0];
  print $out $common1;
  print $out $cdcover_on
    if defined $out_envelop_cdcover and $out eq $out_envelop_cdcover;
  print $out $backcover_on
    if defined $out_envelop_backcover and $out eq $out_envelop_backcover;
  print $out $envelop_12cm_on
    if defined $out_envelop_12cm and $out eq $out_envelop_12cm;
  print $out common2($o->[1]);
  print $out <<"EOP" if defined $opt{B};	# \include has extra \clearpage

\\input{$opt{B}_list}

EOP
}

my $name_long = $out_list_long ? "$opt{B}_list_long" : 'another_list';
my $optional_cont = $out_list_long ? '\iftrue' : '\iffalse';
$optional_cont .= <<'EOP' . <<EOQ . <<'EOP';

  \pagebreak[4]				% Mandatory page break
  \let\PREDIR\PREDIRi			% Reset multicolumn logic

  \def\dirSIZE{\small}
  \def\COLUMNS{3}
  \scriptsize

  {
    \baselineskip 0.8\baselineskip	% Less space before continuation lines
    \PREauthorSKIP 1.2pt\relax		% Pre- and post- level-2 heading
    \POSTauthorSKIP 0.6pt\relax
    % Make this more negative for less skip between non-continuation lines
    \parskip=-0.7pt plus 1pt\relax
EOP
    \\input{$name_long}
EOQ
    \end{multicols}
  }
\fi

\end{document}
EOP

print $out_envelop_cdcover <<'EOP' if $opt{B} and defined $out_envelop_cdcover;
%\end{multicols}
\reportLyricsSyntax
\end{bookletsheets}
%\end{bookletsheetsTwo}
%\end{singlesheet}
\end{document}
EOP

print $out_envelop_backcover <<'EOP' if defined $out_envelop_backcover;
\end{multicols}

\addvspace{0.5ex}
\hrule
%\addvspace{-1.5ex}
\begin{center}
{\bf \small \totalDuration\today}
\end{center}

\reportLyricsSyntax

%\vfill\vfil

\end{backcover-ml}
%\end{backsheet}
%\end{bookletsheets}
%\end{bookletsheetsTwo}
%\end{singlesheet}
\end{document}
EOP

print $out_envelop_text <<'EOP', $optional_cont if defined $out_envelop_text;
\end{multicols}

EOP

print $out_envelop_12cm <<'EOP', $optional_cont if defined $out_envelop_12cm;
\end{multicols}

\addvspace{0.5ex}
\hrule height0.8pt\relax
\vskip 1.2pt
\hrule height1.7pt\relax
%\addvspace{-1.5ex}
\begin{center}
{\bf \small \totalDuration\today}
\end{center}

\reportLyricsSyntax

EOP

if ($opt{B}) {			# Otherwise cdcover is STDOUT...
  (close $_ or warn "Error closing wrapper for write: $!"), undef $_
    for grep defined, $out_envelop_backcover,
      $out_envelop_cdcover, $out_envelop_text, $out_envelop_12cm;
}

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
  undef $previous_long;
  File::Find::find { wanted => \&print_mp3, no_chdir => 1,
		     postprocess => \&unwind_dir,
		     preprocess => \&preprocess_and_sort_with_aligned_numbers },
		'.';
  if ($out_list_long) {
    my $out = select;
    select $out_list_long;
    print_this_mp3({}, $opt_long, $previous_long);	# Flush the postponed data
    select $out;
  }
  print_this_mp3({}, \%opt, $previous);	# Flush the postponed data
  chdir $d or die;
}

if ($opt{T}) {
  $total_sec = to_duration $total_sec;
  print "\\gdef\\totalDuration{Total time: $total_sec. }%\n";
}

close $out_list_long
  or warn "Error closing `$opt{B}_list_long.tex' for write: $!"
  if defined $out_list_long;


print $out_envelop_cdcover <<'EOP' if defined $out_envelop_cdcover;

%\end{multicols}
\reportLyricsSyntax
\end{bookletsheets}
%\end{bookletsheetsTwo}
%\end{singlesheet}
\end{document}
EOP

=head1 NAME

typeset_audio_dir - produce B<TeX> listing of directories with audio files.

=head1 SYNOPSIS

  # E.g.: current directory contains 1 subdirectory-per-performer.
  # Inside each directory the structure is
  #   Composer/single*.mp3              (output <title> field)
  # and
  #   Composer/MultiPart/part*.mp3      (output <album> field)
  # Emit year and duration info
  typeset_audio_dir -y -T -B Quartets *

  # Likewise, but this directory structure is w.r.t. current directory;
  # Do not emit year and duration
  typeset_audio_dir .
  typeset_audio_dir

  # Use artist as toplevel heading, album as the 2nd level; use track numbers;
  # name is based on title for any depth in directory hierarchy;
  # likewise for generation of 2nd level heading.  Mark pieces with lyrics
  typeset_audio_dir -@ -ynTL -1 "@a" -2 "@l" -t 1000 -a 1000 -B All .

  # Likewise, but the name is based on the album; ignore comments
  typeset_audio_dir    -yTn -1 "" -2 ""  -c -t -1e100 -a -1e100 -B All_short .

  # Shortcuts for the last two
  typeset_audio_dir -@ -ynTL -S long     -B All .
  typeset_audio_dir    -yTn  -S short -c -B All_short .

=head1 DESCRIPTION

Scans directory (or directories), using L<MP3::Tag> to obtain
information about audio files (currently only MP3s).  Produces (one or
more) B<TeX> files with the listing.

The intent is to support many different layouts of directories with
audio files with as little tinkering with command-line options as
possible; thus C<type_audio_dir> tries to do as much as possible by
guestimates.  Similtaneously, one should be able to tune the script to
handle the layout they have.

The script emits headers for several levels of "grouping".  The
"toplevel" group header is emited once for every "toplevel" directory
(with audio files), further headers are emited based on changes in
descriptors of the audio files during scan.

=head1 OPTIONS

=over

=item B<-B>

gives basename of the output file.  Without this option the script
will output to STDOUT.  With this option, script separates the layout
from content, and produces 5 B<TeX> files:

  basename_text.tex
  basename_cdcover.tex
  basename_cdbooklet.tex
  basename_backcover.tex
  basename_list.tex

The last file contains the information about audio files encountered.
The others files contain frameworks to typeset this information.

The first four files are supposed to be human-editable; they will not
be overwritten by a following rerun with the same basename given to
the script.  By editing these files, one can choose between several
encodings, languages, multicolumn output, font size, interline
spacing, margins, page size etc.

=item B<-y>

Emit year (or date) information if present.  Very long date
descriptors (e.g., when multiple ranges of dates are present) are
compressed as much as possible.

=item B<-Y>

Emit the whole date information if present.

=item B<-T>

Emit duration information.

=item B<-n>

Emit track number.

=item B<-1>

Toplevel header format; is interpolate()d by L<MP3::Tag> based on
the content of the first audio file encountered during scan of this
toplevel directory.  The default is based on the name of the directory
(with some translation: underscore is converted to space).

=item B<-2>

Second-level heading format; is interpolate()d by L<MP3::Tag>.
Calculated based on the content of each audio file.  The heading is
emited when the interpolated value changes (subject to option L<B<-a>>).

Empty string disables generation.

=item B<-a>

Ignore changes to the second-level heading for directories deeper than
this inside top-level directory.  Defaults to 2.  For example, in

  Performer/Composer/Collection/part1.mp3
  Performer/Composer/Collection/part2.mp3
  Performer/Composer/single1.mp3
  Performer/Composer/single2.mp3

if the toplevel directory is F<Performer>, then changes of the
second-level header in F<single*.mp3> would create a new second-level
heading.  However, similar changes in F<part*.mp3> will not create a
new heading.

B<NOTE:> maybe this default if 2 is not very intuitive.  It is
recommended to explicitely set this option to the value you feel
appropriate (C<1e100> would play role of infinity).

=item B<-t>

The title-cutoff depth (w.r.t. toplevel directory).  Defaults to 2.
In audio files deeper than this the album C<%l> is used as the name;
otherwise the title C<%t> of the audio file is used.

Set to C<-1e100> to always use C<%l>, and to C<1e100> to always use C<%a>.

=item B<-@>

Replace all C<@> by C<%> in options.  Very useful with DOSISH shells
to include C<%>-escapes necessary for L<MP3::Tag>'s interpolate().

=item B<-e ENCODINGS>

Sets encodings for output files, directory names (when uses to generate
headings), and hint files.  B<ENCODINGS> is a comma-separated list of
directives; each directive is either an encoding name (to use for all targets),
or C<TARGET_LETTERS:encoding>.  Target letters are C<o>, C<d>, and C<h>
correspondingly.  Use 0 instead of an encoding to do byte-oriented read/write.

=item B<-c>

If not given, the frame C<TXXX[add-to:file-by-person,l,t,n]> will be
inspected, and used as a "comment" for a record.

=item B<-S STYLE>

a shortcut for setting options C<-1 -2 -a -t> to specific values given in
L<"SYNOPSIS">:

  long:  -1 "@a" -2 "@l" -t  1e100 -a  1e100
  short: -1 ""   -2 ""   -t -1e100 -a -1e100


=back

=head1 Info read from file system

The following files are used to give hints to F<typeset_audio_dir>:

=over

=item F<.content_comment>

Content of this file is used as a comment field in the output for all
files in this directory.

=item F<.top_heading>

If empty, indicates that when the depth of files modifies the output,
it is calculated w.r.t. the subdirectories of the directory of this
file (ouph!).  If contains a number, it is added to this depth.

Otherwise the content of this file is used as a toplevel heading for
this directory.

=back

=head1 TYPESETTING

Running this script will only generate necessary TeX files, but will
not typeset them (they will look much better if you first edit the
files to suit your needs).  Recall how to typeset TeX documents (here
we assume PDF target):

  latex document.tex && dvips document.dvi && ps2pdf document

(a lot of temporary files are going to be generated too).  Some of the
files (e.g., F<..._cdcover.tex>) assume work better with landscape
orientation; one needs

  latex document.tex && dvips -t landscape document.dvi && ps2pdf document

With F<..._cdbooklet.tex>, for best result, one better should
rearrange pages for booklet 2up 2-pages-per-side printing:

  latex document.tex
    && dvips -t landscape -f < document.dvi | psbook | pstops "2:0(0,-6cm)+1(0,6cm)" > document.ps
    && ps2pdf document

(more details on running dvips is put in the beginning of this TeX file).

=head1 HINTS

Do not forget that if you can't describe a complicated layout by
command-line options, you still have a possibility to run this script
many times (once per directory with "handable layout", using B<-B> and
other options suitable for this subdirectory).  Then you can use
B<LaTeX> C<\input> directives to include the generated files into the
toplevel C<LaTeX> file.

You can also redefine C<\preDir * \posDir> to do nothing, and put the
necessary code to generate the headers into the top-level file.

Modify the formatting macros to suit your needs.

One can combine two (or more) lists (e.g., with the short style, and
the long style) into one output file; the generated files
F<..._cdbooklet.tex> and F<..._text.tex> already have a necessary
template (disabled) at the end.  For example, with two lists created in
L<"SYNOPSIS">, F<All_list.tex>, and F<All_short_list.tex>, find
C<\iffalse> near the end of F<All_short_cdbooklet.tex> and change it
to C<\iftrue>; then change the name in the directive

    \input{another_list}

to F<All_long_list>

This will make the "short" cdbooklet become a kind of "table of
contents" for the combined "short+long" cdbooklet.  (Of course, one
can change the values of macros C<\dirSIZE>, C<\COLUMNS>, size of
skips and of type [as C<\scriptsize> above] to suit your needs - the
point is that they should not be necessarily the same for the second list.)

=cut

