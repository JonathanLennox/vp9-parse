#!/usr/bin/perl

$^W = 1;
use strict;

sub t($)
{
    my ($x) = @_;
    return $x != 0 ? 1 : 0;
}

sub parse_payload($)
{
    my ($payload) = @_;
    my $b1 = ord(substr($payload, 0, 1));
    
    my $i = t($b1 & 0x80);
    my $p = t($b1 & 0x40);
    my $l = t($b1 & 0x20);
    my $f = t($b1 & 0x10);
    my $b = t($b1 & 0x08);
    my $e = t($b1 & 0x04);
    my $v = t($b1 & 0x02);
    my $z = t($b1 & 0x01);

    my $ret = "i=$i p=$p l=$l v=$f b=$b e=$e v=$v z=$z";

    my $of = 1;
    
    if ($i) {
        my $m = t(ord(substr($payload, $of, 1)) & 0x80);
        if ($m) {
            my $pid = unpack("n", substr($payload, $of, 2)) & 0x7fff;
            $ret .= " pid=$pid/15";
            $of += 2;
        }
        else {
            my $pid = ord(substr($payload, $of, 2)) & 0x7f;
            $ret .= " pid=$pid/7";
            $of += 1;
        }
    }

    if ($l) {
        my $lb = ord(substr($payload, $of, 1));
        my $tid = ($lb & 0xe0) >> 5;
        my $u = t($lb & 0x10);
        my $sid = ($lb & 0x0e) >> 1;
        my $d = t($lb & 0x01);

        $ret .= " tid=$tid u=$u sid=$sid d=$d";

        $of += 1;
        if (!$f) {
            my $tl0picidx = ord(substr($payload, $of, 1));
            $ret .= " tl0picidx=$tl0picidx";
            $of += 1;
        }
    }

    if ($f && $p) {
        $ret .= " pdiff=";
        my $first = 1;
        my $n;
        do {
            my $pn = ord(substr($payload, $of, 1));
            my $pdiff = $pn >> 1;
            $n = t($pn & 0x01);
            if (!$first) {
                $ret .= "/";
            }
            $ret .= $pdiff;
            $first = 0;
            $of++;
        } while ($n);
    }

    if ($v) {
        $ret .= " SS=[";
        my $s1 = ord(substr($payload, $of, 1));
        my $ns = ($s1 & 0xe0) >> 5;
        my $y = t($s1 & 0x10);
        my $g = t($s1 & 0x08);

        $ret .= $ns + 1 . " lyrs";
        $of++;
        if ($y) {
            $ret .= ":";
            my $first = 1;
            for (0..$ns) {
                my ($width, $height) = unpack("nn", substr($payload, $of, 4));
                if (!$first) {
                    $ret .= "/";
                }
                $ret .= "${width}x${height}";
                $first = 0;
                $of += 4;
            }
        }

        if ($g) {
            my $ng = ord(substr($payload, $of, 1));
            $of += 1;
            my $first_g = 1;
            $ret .= ";PG=$ng:";
            for (0..$ng-1) {
                my $gh = ord(substr($payload, $of, 1));
                $of++;
                my $tid = ($gh & 0xe0) >> 5;
                my $u = t($gh & 0x10);
                my $r = ($gh & 0x0c) >> 2;
                if (!$first_g) {
                    $ret .= ";"
                }
                $ret .= $tid;
                if ($u) {
                    $ret .= "[u]";
                }
                $ret .= ":";
                my $first_diff = 1;
                for (0..$r-1) {
                    my $pdiff = ord(substr($payload, $of, 1));
                    $of++;
                    if (!$first_diff) {
                        $ret .= '-';
                    }
                    $ret .= $pdiff;
                    $first_diff = 0;
                }
                $first_g = 0;
            }
        }
        $ret .= "]";
    }
    
    return $ret;
}

while (<>) {
    if (/(.*) data=([a-z0-9]*)/) {
        my $header_desc = $1;
        my $payload = pack("H*", $2);

        my $payload_desc = parse_payload($payload);

        print "$header_desc $payload_desc\n";
    }
}
