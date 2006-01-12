#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..75\n"; }
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

{local *F; open F, '>test12.mp3' or warn; print F 'empty'}

$mp3 = MP3::Tag->new("test12.mp3");
ok($mp3, "Got tag");
ok(scalar ($mp3->config('parse_data',['mz', 'another text', '%{TXXX[foo]}']), 1),
   "config parsedata TXXX[foo]");
ok($mp3->title, "prepare the data");
ok($mp3->interpolate('%{TXXX}'), "have TXXX");
ok(!$mp3->interpolate('%{TXXX01}'), "no TXXX01");
ok(!$mp3->interpolate('%{TXXX02}'), "no TXXX02");

ok($mp3->update_tags, 'update');

ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
ok($mp3->title, "prepare the data");
ok($mp3->interpolate('%{TXXX}'), "have TXXX");
ok(!$mp3->interpolate('%{TXXX01}'), "no TXXX01");
ok(!$mp3->interpolate('%{TXXX02}'), "no TXXX02");

ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
ok($mp3->select_id3v2_frame('COMM', 'short', 'yyy', 'this is my COMM(yyy)[short]'), "select_id3v2_frame for write");
ok($mp3->update_tags, 'update');

ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
ok($mp3->select_id3v2_frame('COMM', 'short', 'yyy') eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM', 'short', 'yYy') eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM', 'short', '') eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");

# these returns hash
ok($mp3->select_id3v2_frame('COMM', 'short', undef)->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read, lang=undef");
ok($mp3->select_id3v2_frame('COMM', 'short')->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");

ok(! defined ($mp3->select_id3v2_frame('COMM', 'short', [])), "select_id3v2_frame for read, empty lang");
ok($mp3->select_id3v2_frame('COMM', undef, 'yyy')->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM', undef, 'yYy')->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM', undef, '')->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM', undef, undef)->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read, Lang/descr are undef");
ok($mp3->select_id3v2_frame('COMM', undef)->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok($mp3->select_id3v2_frame('COMM')->{Text} eq 'this is my COMM(yyy)[short]', "select_id3v2_frame for read");
ok((not defined $mp3->select_id3v2_frame('COMM', '', [])), "select_id3v2_frame for read");

# Check growth of tags
ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
$mp3->get_tags;
my $osize = $mp3->{ID3v2}->{tagsize};
ok($osize>0, 'got size');
ok($mp3->select_id3v2_frame('COMM', 'short', 'yyy', 'my COMM(yyy)[short]'), "select_id3v2_frame for write, make shorter");
ok($mp3->update_tags, 'update');

ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
$mp3->get_tags;
my $nsize = $mp3->{ID3v2}->{tagsize};
ok($nsize>0, 'got size');
ok($nsize <= $osize, 'size did not grow');
ok($mp3->select_id3v2_frame('COMM', 'short', 'yyy', 'this is my COMM(yyy)[short]'), "select_id3v2_frame for write, make longer - as it was");
ok($mp3->update_tags, 'update');

ok($mp3 = MP3::Tag->new("test12.mp3"), 'reinit ourselves');
$mp3->get_tags;
my $nnsize = $mp3->{ID3v2}->{tagsize};
ok($nnsize>0, 'got size');
ok($nnsize >= $nsize, 'size did not shrink');
ok($nnsize <= $osize, 'size did not grow w.r.t. initial size');
#print STDERR "sizes: $osize, $nsize, $nnsize\n";

MP3::Tag->config(id3v2_shrink => 1);
MP3::Tag->config(id3v2_mergepadding => 1);
{local *F; open F, '>test13.mp3' or warn; print F "\0" x 1500, "\1", "\0" x 1499}

sub has_1 ($;$) {
  my ($f, $has_v1) = (shift, shift) or die;
  open F, "<$f" or die;
  binmode F;
  seek F, 0, 2 or die "seek-end: $!";
  my $p = tell F;
  my $off = 1500 + ($has_v1 ? 128 : 0);
  # print STDERR "off=$p ($f) ", -s $f, "\n";
  return 0 unless $p >= $off;
  seek F, -$off, 2 or die "seek -$off: $!";
  read F, my $in, 1 or die;
  close F or die;
  return $in eq "\1";
}

ok(has_1("test13.mp3"), "has 1");

ok($mp3 = MP3::Tag->new("test13.mp3"), 'reinit from new file');
$mp3->get_tags;
ok($mp3->update_tags({title => "Some very very very very very very long title"}), 'update');
ok(int((511 + -s 'test13.mp3')/512)
   == int((511 + 3000 + 10 + $mp3->{ID3v2}->{tagsize})/512), 'size ok (but this may change if we look for padding more aggressively)');

my $ts = $mp3->{ID3v2}->{tagsize};

ok(has_1("test13.mp3", 1), "has 1");

ok($mp3 = MP3::Tag->new("test13.mp3"), 'reinit');
$mp3->get_tags;
ok($mp3->{ID3v2}->{tagsize} == $ts, 'tagsize the same');
ok($mp3->{ID3v2}->{buggy_padding_size} == 1500, 'padding_size the same');
#print STDERR "padding_found: $mp3->{ID3v2}->{padding_size}\n";
ok($mp3->update_tags({title => "Another very very very very very very long title"}), 'update');

ok($mp3->{ID3v2}->{tagsize} <= 512+128+100, 'tagsize small enough');

ok(has_1("test13.mp3", 1), "has 1");
ok($mp3->title =~ /Another/, "Title preserved");

ok($mp3 = MP3::Tag->new("test13.mp3"), 'reinit');
$mp3->get_tags;
#print STDERR "padding_found: $mp3->{ID3v2}->{padding_size}\n";
ok($mp3->update_tags({title => "Other very very very very very very long title"}), 'update');

ok($mp3->{ID3v2}->{tagsize} <= 512+128+100, 'tagsize small enough');

#undef $mp3;
ok(has_1("test13.mp3", 1), "has 1");
ok($mp3->title =~ /Other/, "Title preserved");


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
