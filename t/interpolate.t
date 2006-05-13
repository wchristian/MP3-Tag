#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..8\n"; $ENV{MP3TAG_SKIP_LOCAL} = 1}
END {print "MP3::Tag not loaded :(\n" unless $loaded;}
use MP3::Tag;
$loaded = 1;
$count = 0;
ok(1,"MP3::Tag initialized");

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

{local *F; open F, '>test12.mp3' or warn; print F 'empty'}
{local *F; open F, '>xxxtest12.mp3' or warn; print F 'content'}

$mp3 = MP3::Tag->new("test12.mp3");

ok( $mp3->interpolate('%{TCOM: %{TCOM} }') eq '',  'false conditional');
ok( $mp3->interpolate('%{TCOM|| <%{TCOM}> }') eq ' <> ',  'false ||-interpolation');
my $res = $mp3->interpolate('aa%{I(f)xxxtest12.mp3}bb');
print "# `$res'\n";
ok($res eq 'aacontentbb', "I(f) interpolates");
$res = $mp3->interpolate('aa%{I(if)xxx%f}bb');
ok($res eq 'aacontentbb', "I(fi) interpolates");
$res = $mp3->interpolate('aa%{I(if)xxx%{f||not_present}}bb');
ok($res eq 'aacontentbb', "I(fi) interpolates with choice");
$res = $mp3->interpolate('aa%{I(if)%{!y:xxx%{f||not_present}}}bb');
ok($res eq 'aacontentbb', "I(fi) interpolates with conditional with choice ");
$res = $mp3->interpolate('aa%{COMM03:%{I(if)%{!y:xxx%{f||not_present}}}}bb');
ok($res eq 'aabb', "I(fi) interpolates in conditional");

my @failed;
#@failed ? die "Tests @failed failed.\n" : print "All tests successful.\n";

sub ok_test {
  my ($result, $test) = @_;
  printf ("Test %2d %s %s", ++$count, $test, '.' x (45-length($test)));
  (push @failed, $count), print " not" unless $result;
  print " ok\n";
}
sub ok {
  my ($result, $test) = @_;
  (push @failed, $count), print "not " unless $result;
  printf "ok %d # %s\n", ++$count, $test;
}
