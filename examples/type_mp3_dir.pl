#!/usr/bin/perl -w

use strict;
use MP3::Tag;
use File::Find;
use Getopt::Std 'getopts';
use Cwd;

my %opt = (2 => '%a');
getopts('2:1:yY@', \%opt);	# Level-2 header; Level-1 header (default - dir), year, whole dates, replace @ by %
if ($opt{'@'}) {
  $opt{$_} =~ s/\%/\@/ for keys %opt;
}

# suppose that the directory structure is author/TIT1/TIT2.mp3 or author/TIT2.mp3
# and TIT1 eq "%l"
my $author = '';
my $TIT1 = '';
my $had_subdir;
my $print_dir;
# $|=1;					# For debugging

sub to_TeX ($) {
  (my $in = shift) =~ s/([&_\$#%])/\\$1/g;
  $in =~ s/\.{3}/\\dots{}/g;
  $in =~ s/\bDvorák\b/Dvo\\v rák/g;
  $in;
}
sub print_mp3 {
  return unless -f $_ and /\.mp3$/i;
  my $tag = MP3::Tag->new($_);
  my @parts = split m<[/\\]>, $File::Find::dir;
  shift @parts if @parts and $parts[0] eq '.';
  # warn "author uninit for `$File::Find::name'" unless defined $author;
  # warn "TIT1 uninit for `$File::Find::name'" unless defined $TIT1;
  if (defined $print_dir) {
    $print_dir = $tag->interpolate($opt{1}) if $opt{1};
    print "\n\\preDir ";
    print to_TeX $print_dir;
    print "\\postDir\n";
    undef $print_dir;
  }
  if ( @parts ? (not length $author or $author ne $parts[0]) : $had_subdir ) {
    print "\n\\preauthor ";
    print to_TeX $tag->interpolate($opt{2});
    print "\\postauthor\n";
    $author = $parts[0];
  }
  $had_subdir = @parts;
  my $fcomment = "$File::Find::dir/.content_comment";
  my $comment = '';
  if (-f $fcomment) {
    local $/;
    local *F;
    open F, "< $fcomment" or die "open `$fcomment' failed: $!";
    $comment = <F>;
    $comment =~ s/^\s+//;
    $comment =~ s/\s+$//;
    $comment = "\\precomment " . to_TeX($comment) . "\\postcomment ";
  }
  my $year = $opt{y} ? $tag->year : '';
  $year =~ s/(\d)-(?=\d{4})/$1--$2/g;
  # Contract long dates (with both ',' and '-')
  if ($year and $year =~ /,/ and $year =~ /-/ and not $opt{Y}) {
    $year =~ s/-?(-\d\d?\b)+//g;	# Remove month etc
    1 while $year =~ s/\b(\d{4})(?:,|--)\1/$1/g;	# Remove "the same" year
    (my $y = $year) =~ s/--/,/g;
    # Remove intermediate dates if more than 3 years remain
    $year =~ s/(,|--).*(,|--)/--/ if ($y =~ tr/,//) > 2;
  }
  $year = "\\preyear $year\\postyear" if $year;
  if (@parts <= 1) {
    print "\\pretitle ";
#    print "}\n{\$\\quad\$ ";
    print to_TeX $tag->interpolate('%t');
    print "$comment$year\\posttitle\n";
    $TIT1 = '';
  } elsif (not length $TIT1 or $TIT1 ne $parts[1]) {
    print "\\pretitle ";
#    print "}\n{\$\\quad\$ ";
    print to_TeX $tag->interpolate('%l');
    print "$comment$year\\posttitle\n";
    $TIT1 = $parts[1];
  }
}

print <<'EOP';
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
\def\preauthor{\pagebreak[1]\bgroup\centering\bf}
\def\postauthor{\par\egroup}
\def\pretitle{}
\def\posttitle{\par}
\def\precomment{ \bgroup\it}
\def\postcomment{\egroup}
\def\preyear{ \hfill[}
\def\postyear{]}
\CDbookletMargin=1.5mm
\CDbookletTopMargin=1.5mm
\CDsingleMargin=1.5mm
\CDsingleTopMargin=1.5mm
\parindent=0pt
% Make this more negative for denser type
\parskip=-1.1pt plus 1.1pt\relax
\begin{bookletsheets}
%\begin{bookletsheetsTwo}
%\begin{singlesheet}{Title}{Slip text}

%\begin{multicols}{4}

% Choose a size which better fits the pages...
%\small
\footnotesize
%\scriptsize
%\tiny
EOP

my $d = Cwd::cwd;
for (@ARGV) {
  $had_subdir = 0;
  warn("Not a directory: `$_'"), next unless -d;
  chdir $_ or die "Can't chdir `$_'";
  (my $name = $_) =~ s,.*[/\\](?!$),,;
  $name =~ s/_/ /g;
  $print_dir = $name;
#  print <<EOP;
#\\preDir $name\\postDir
#EOP
  $author = '';
  $TIT1 = '';
  File::Find::find { wanted => \&print_mp3, no_chdir => 1 }, '.';
  chdir $d or die;
}

print <<'EOP';
%\end{multicols}
\end{bookletsheets}
%\end{bookletsheetsTwo}
%\end{singlesheet}
\end{document}
EOP
