#
# Copyright @ 2021 - present 8x8, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
