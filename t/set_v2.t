#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..16\n"; }
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

$mp3 = MP3::Tag->new("test12.mp3");
ok($mp3, "Got tag");
ok(scalar ($mp3->set_id3v2_frame('TIT1','this is my tit1'),1), "set_id3v2_frame");

ok($mp3->{ID3v2}, "ID3v2 tag autocreated");
ok(($mp3->{ID3v2} and $mp3->{ID3v2}->write_tag),"Writing ID3v2");

$mp3 = MP3::Tag->new("test12.mp3");

ok($mp3->title() eq 'this is my tit1',"Got ID3v2");

{local *F; open F, '>test12.mp3' or warn; print F 'empty'}

$mp3 = MP3::Tag->new("test12.mp3");
ok($mp3, "Got tag");

my $res = $mp3->parse('%{TIT2}', 'another tit1');
ok($res, "parse %{TIT2}");
ok(1 == scalar keys %$res, "1 key");
#warn keys %$res;
ok($res->{TIT2} eq 'another tit1', "key TIT2");

{local *F; open F, '>test12.mp3' or warn; print F 'empty'}

$mp3 = MP3::Tag->new("test12.mp3");
ok($mp3, "Got tag");
ok(scalar ($mp3->config('parse_data',['mz', 'another tit1', '%{TIT2}']), 1),
   "config parsedata");
$t = $mp3->title;
#warn "tit '$t'";
ok($t, "checking a field");

ok($mp3->{ID3v2}, "ID3v2 tag autocreated");
ok(($mp3->{ID3v2} and $mp3->{ID3v2}->write_tag),"Writing ID3v2");

$mp3 = MP3::Tag->new("test12.mp3");

ok($mp3->title() eq 'another tit1',"Got ID3v2");

my @failed;
@failed ? die "Tests @failed failed.\n" : print "All tests successful.\n";

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
