package BitBuffer;

use strict;

use Class::Tiny qw(buffer), {
    offset => 0
};

sub bit {
    my $self = shift;
    my $off = $self->offset();
    my $buflen = length($self->{buffer});
    my $bufidx = $off / 8;
    my $bitidx = $off % 8;

    die "offset $off invalid in buffer of length $buflen" if $bufidx >= $buflen;

    my $mask = 1 << (7 - $bitidx);
    my $byte = ord(substr($self->{buffer}, $bufidx, 1));

    $self->{offset}++;

    return ($byte & $mask) != 0 ? 1 : 0;
}

sub byte_offset {
    my $self = shift;
    my $off = $self->{offset};
    my $bufidx = $off / 8;
    my $bitidx = $off % 8;

    die "offset $off not at a byte boundary" if $bitidx != 0;

    return $bufidx;
}

sub bits($) {
    my ($self, $bits) = @_;

    my $ret = 0;

    # Could optimize this
    for (0..$bits-1) {
        $ret <<= 1;
        $ret |= $self->bit();
    }

    return $ret;
}

sub skipbits($) {
    my ($self, $bits) = @_;
    
    $self->{offset} += $bits;
}

1;
