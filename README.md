# VP9 parser
Quick and dirty VP9 RTP parser for debugging VP9 bitstreams.  Parses both the VP9 RTP payload header
and (most of) the VP9 bitstream uncompressed header.

Operates on the output of `rtpdump -F hex` from [rtptools](https://github.com/irtlab/rtptools).

Wireshark can output rtpdump-format files from the "Telephony / RTP / RTP Streams / Export..." menu.

It should be pretty easy to adapt to anything that can produce a VP9 RTP packet.
