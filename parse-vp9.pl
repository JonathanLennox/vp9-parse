#!/usr/bin/perl

$^W = 1;
use strict;

use lib '.';
use BitBuffer;

sub t($)
{
    my ($x) = @_;
    return $x != 0 ? 1 : 0;
}

sub parse_payload($)
{
    my ($buf) = @_;
    
    my $i = $buf->bit();
    my $p = $buf->bit();
    my $l = $buf->bit();
    my $f = $buf->bit();
    my $b = $buf->bit();
    my $e = $buf->bit();
    my $v = $buf->bit();
    my $z = $buf->bit();

    my $ret = "i=$i p=$p l=$l v=$f b=$b e=$e v=$v z=$z";

    if ($i) {
        my $m = $buf->bit();
        if ($m) {
            my $pid = $buf->bits(15);
            $ret .= " pid=$pid/15";
        }
        else {
            my $pid = $buf->bits(7);
            $ret .= " pid=$pid/7";
        }
    }

    if ($l) {
        my $tid = $buf->bits(3);
        my $u = $buf->bit();
        my $sid = $buf->bits(3);
        my $d = $buf->bit();

        $ret .= " tid=$tid u=$u sid=$sid d=$d";

        if (!$f) {
            my $tl0picidx = $buf->bits(8);
            $ret .= " tl0picidx=$tl0picidx";
        }
    }

    if ($f && $p) {
        $ret .= " pdiff=";
        my $first = 1;
        my $n;
        do {
            my $pdiff = buf->bits(7);
            $n = buf->bit();
            if (!$first) {
                $ret .= "/";
            }
            $ret .= $pdiff;
            $first = 0;
        } while ($n);
    }

    if ($v) {
        $ret .= " SS=[";
        my $ns = $buf->bits(3);
        my $y = $buf->bit();
        my $g = $buf->bit();
        $buf->skipbits(3);

        $ret .= $ns + 1 . " lyrs";
        if ($y) {
            $ret .= ":";
            my $first = 1;
            for (0..$ns) {
                my $width = $buf->bits(16);
                my $height = $buf->bits(16);
                if (!$first) {
                    $ret .= "/";
                }
                $ret .= "${width}x${height}";
                $first = 0;
            }
        }

        if ($g) {
            my $ng = $buf->bits(8);
            my $first_g = 1;
            $ret .= ";PG=$ng:";
            for (0..$ng-1) {
                my $tid = $buf->bits(3);
                my $u = $buf->bit();
                my $r = $buf->bits(2);
                $buf->skipbits(2);
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
                    my $pdiff = $buf->bits(8);
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

    $ret .= " payload=" . unpack("H*", substr($buf->buffer(), $buf->byte_offset()));

    return $ret;
}

while (<>) {
    if (/(.*) data=([a-z0-9]*)/) {
        my $header_desc = $1;
        my $payload = pack("H*", $2);

        my $buffer = new BitBuffer(buffer => $payload);

        my $payload_desc = parse_payload($buffer);

        print "$header_desc $payload_desc\n";
    }
}
