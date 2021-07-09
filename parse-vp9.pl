#!/usr/bin/perl

$^W = 1;
use strict;
use Try::Tiny;

use lib '.';
use BitBuffer;


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

    $ret .= "\n\t";

    if ($b) {
        $ret .= parse_vp9($buf);
    }
    else {
        $ret .= "[continuation]";
    }

    return $ret;
}

sub parse_vp9($)
{
    my ($buf) = @_;

    return parse_uncompressed_header($buf);
    # Not bothering to get into the arithmetic-coded section.
}

%::frame_type_name = (
    0 => "KEY_FRAME",
    1 => "NON_KEY_FRAME"
);

%::color_space_name = (
    0 => "CS_UNKNOWN",
    1 => "CS_BT_601",
    2 => "CS_BT_709",
    3 => "CS_SMPTE_170",
    4 => "CS_SMPTE_240",
    5 => "CS_BT_2020",
    6 => "CS_RESERVED",
    7 => "CS_RGB"
);

sub parse_uncompressed_header($)
{
    my ($buf) = @_;

    my $frame_marker = $buf->bits(2);
    my $profile = $buf->bits(2);
    my $ret = "frame_marker=$frame_marker profile=$profile";

    if ($profile == 3) {
        # reserved_zero
        $buf->skipbits(1);
    }

    my $show_existing_frame = $buf->bit();
    $ret .= " show_existing_frame=$show_existing_frame";
    if ($show_existing_frame) {
        my $frame_to_show_map_idx = $buf->bits(3);
        $ret .= " frame_to_show_map_idx=$frame_to_show_map_idx";
        return $ret;
    }

    my $frame_type = $buf->bit(1);
    my $show_frame = $buf->bit(1);
    my $error_resilient_mode = $buf->bit(1);

    $ret .= " frame_type=$::frame_type_name{$frame_type} show_frame=$show_frame error_resilient_mode=$error_resilient_mode";

    my $FrameIsIntra;
    if ($frame_type == 0) # KEY_FRAME
    {
        $ret .= parse_frame_sync_code($buf);
        $ret .= parse_color_config($buf, $profile);
        $ret .= parse_frame_size($buf);
        $ret .= parse_render_size($buf);
        $ret .= " [refresh_frame_flags=" . format_refresh_frame_flags(0xff) . "]";
        $FrameIsIntra = 1;
    }
    else {
        my $intra_only;
        if ($show_frame == 0) {
            $intra_only = $buf->bit();
            $ret .= " intra_only=$intra_only";
        }
        else {
            $intra_only = 0;
        }
        $FrameIsIntra = $intra_only;

        if ($error_resilient_mode == 0) {
            my $reset_frame_context = $buf->bits(2);
            $ret .= " reset_frame_context=$reset_frame_context";
        }
        if ($intra_only == 1) {
            $ret .= parse_frame_sync_code($buf);
            if ($profile > 0) {
                $ret .= parse_color_config($buf, $profile);
            }
            my $refresh_frame_flags = $buf->bits(8);
            $ret .= " refresh_frame_flags=" . format_refresh_frame_flags($refresh_frame_flags);

            $ret .= parse_frame_size($buf);
            $ret .= parse_render_size($buf);
        }
        else {
            my $refresh_frame_flags = $buf->bits(8);
            $ret .= " refresh_frame_flags=" . format_refresh_frame_flags($refresh_frame_flags);
            for (my $i = 0; $i < 3; $i++) {
                my $ref_frame_idx = $buf->bits(3);
                my $ref_frame_sign_bias = $buf->bit();
                $ret .= " ref_frame_idx[$i]=$ref_frame_idx ref_frame_sign_bias[LF+$i]=$ref_frame_sign_bias";
            }
            $ret .= parse_frame_size_with_refs($buf);

            my $allow_high_precision_mv = $buf->bit();
            $ret .= " allow_high_precision_mv=$allow_high_precision_mv";

            $ret .= parse_read_interpolation_filter($buf)
        }
    }
    if ($error_resilient_mode == 0) {
        my $refresh_frame_context = $buf->bit();
        my $frame_parallel_decoding_mode = $buf->bit();

        $ret .= " refresh_frame_context=$refresh_frame_context frame_parallel_decoding_mode=$frame_parallel_decoding_mode";
    }
    my $frame_context_idx = $buf->bits(2);
    $ret .= " frame_context_idx=$frame_context_idx";

    $ret .= parse_loop_filter_params($buf);

    $ret .= parse_quantization_params($buf);

    $ret .= parse_segmentation_params($buf);

    # tile_info is the point at which the uncompressed header becomes not independently parseable
    # outside of full decoding context - its parsing depends on FrameWidth, which in some cases is
    # inferred from the reference frame.

    return $ret;
}

sub format_refresh_frame_flags($) {
    my ($flags) = @_;

    my $ret = "{";
    my $first = 1;

    for (my $i = 0; $i < 8; $i++) {
        if ($flags & (1 << $i)) {
            if (!$first) {
                $ret .= ",";
            }
            $ret .= $i;
            $first = 0;
        }
    }
    $ret .= "}";
    return $ret;
}

sub parse_frame_sync_code($) {
    my ($buf) = @_;

    my $frame_sync_code = $buf->bits(24);

    return sprintf " frame_sync_code=%#06x", $frame_sync_code;
}

sub parse_color_config($) {
    my ($buf, $profile) = @_;
    my $ret = "";

    if ($profile >= 2) {
        my $ten_or_twelve_bit = $buf->bit();
        $ret .= " ten_or_twelve_bit=$ten_or_twelve_bit";
    }

    my $color_space = $buf->bits(3);
    $ret .= " color_space=$::color_space_name{$color_space}";

    if ($color_space != 7) { # CS_RGB
        my $color_range = $buf->bit();
        $ret .= " color_range=$color_range";
        if ($profile == 1 || $profile == 3) {
            my $subsampling_x = $buf->bit();
            my $subsampling_y = $buf->bit();
            $buf->skipbits(1); # reserved_zero;
        }
    }
    else {
        if ($profile == 1 || $profile == 3) {
            $buf->skipbits(1); # reserved_zero;
        }
    }

    return $ret;
}

sub parse_frame_size($) {
    my ($buf) = @_;

    my $frame_width_minus_1 = $buf->bits(16);
    my $frame_height_minus_1 = $buf->bits(16);

    my $FrameWidth = $frame_width_minus_1 + 1;
    my $FrameHeight = $frame_height_minus_1 + 1;

    return " FrameWidth=$FrameWidth FrameHeight=$FrameHeight";
}

sub parse_render_size($) {
    my ($buf) = @_;

    my $render_and_frame_size_different = $buf->bit();
    my $ret = " render_and_frame_size_different=$render_and_frame_size_different";

    if ($render_and_frame_size_different == 1) {
        my $render_width_minus_1 = $buf->bits(16);
        my $render_height_minus_1 = $buf->bits(16);

        my $RenderWidth = $render_width_minus_1 + 1;
        my $RenderHeight = $render_height_minus_1 + 1;

        $ret .= " RenderWidth=$RenderWidth RenderHeight=$RenderHeight";
    }

    return $ret;

}

sub parse_frame_size_with_refs($) {
    my ($buf) = @_;

    my $ret = "";
    my $found_ref;
    for (my $i = 0; $i < 3; $i++) {
        $found_ref = $buf->bit();
        $ret .= " found_ref[$i]=$found_ref";
        if ($found_ref == 1) {
            last;
        }
    }

    if ($found_ref == 0) {
        $ret .= parse_frame_size($buf);
    }
    else {
        # compute_image_size [no bits read from bitstream];
    }
    $ret .= parse_render_size($buf);

    return $ret;
}

sub parse_read_interpolation_filter($) {
    my ($buf) = @_;

    my $is_filter_switchable = $buf->bit();
    my $ret = " is_filter_switchable=$is_filter_switchable";

    if ($is_filter_switchable == 1) {
        my $raw_interpolation_filter = $buf->bits(2);
        $ret .= " raw_interpolation_filter=$raw_interpolation_filter";
    }

    return $ret;
}

sub parse_loop_filter_params($) {
    my ($buf) = @_;

    my $loop_filter_level = $buf->bits(6);
    my $loop_filter_sharpness = $buf->bits(3);
    my $loop_filter_delta_enabled = $buf->bit();

    my $ret = " loop_filter_level=$loop_filter_level loop_filter_sharpness=$loop_filter_sharpness loop_filter_delta_enabled=$loop_filter_delta_enabled";

    if ($loop_filter_delta_enabled == 1) {
        my $loop_filter_delta_update = $buf->bit();
        $ret .= " loop_filter_delta_update=$loop_filter_delta_update";

        if ($loop_filter_delta_update == 1) {
            for (my $i = 0; $i < 4; $i++) {
                my $update_ref_delta = $buf->bit();
                if ($update_ref_delta == 1) {
                    my $loop_filter_ref_deltas_i = $buf->bits(6);
                    $ret .= " loop_filter_ref_deltas[$i]=$loop_filter_ref_deltas_i";
                }
            }
            for (my $i = 0; $i < 2; $i++) {
                my $update_mode_delta = $buf->bit();
                if ($update_mode_delta == 1) {
                    my $loop_filter_mode_deltas_i = $buf->bits(6);
                    $ret .= " loop_filter_mode_deltas[$i]=$loop_filter_mode_deltas_i";
                }
            }
        }
    }

    return $ret;
}

sub parse_quantization_params($) {
    my ($buf) = @_;

    my $base_q_idx = $buf->bits(8);

    my $ret = " base_q_idx=$base_q_idx";

    $ret .= " delta_q_y_dc=" . read_delta_q($buf);
    $ret .= " delta_q_uv_dc=" . read_delta_q($buf);
    $ret .= " delta_q_uv_ac=" . read_delta_q($buf);

    return $ret;
}

sub read_delta_q($) {
    my ($buf) = @_;

    my $delta_coded = $buf->bit();

    if ($delta_coded == 1) {
        my $delta_q_val = $buf->bits(3);
        my $delta_q_sign = $buf->bit();
        my $delta_q = $delta_q_sign ? -$delta_q_val : $delta_q_val;

        return "$delta_q";
    }
    else {
        return "(0)";
    }
}

$::MAX_SEGMENTS = 8;
$::SEG_LVL_MAX = 4;
@::segmentation_feature_bits = (8, 6, 2, 0);
@::segmantation_feature_signed = (1, 1, 0, 0);

sub parse_segmentation_params($) {
    my ($buf) = @_;

    my $segmentation_enabled = $buf->bit();

    my $ret = " segmentation_enabled=$segmentation_enabled";

    if ($segmentation_enabled == 1) {
        my $segmentation_update_map = $buf->bit();
        for (my $i = 0; $i < 7; $i++) {
            my $segmentation_tree_prob = read_prob($buf);
            $ret .= " segmentation_tree_probs[$i]=$segmentation_tree_prob";
        }
        my $segmentation_temporal_update = $buf->bit();
        for (my $i = 0; $i < 3; $i++) {
            if ($segmentation_temporal_update) {
                my $segmentation_pred_prob = read_prob($buf);
                $ret .= " segmentation_pred_prob[$i]=$segmentation_pred_prob";
            }
        }

        my $segmentation_update_data = $buf->bit();
        $ret .= " segmentation_update_data=$segmentation_update_data";

        if ($segmentation_update_data == 1) {
            my $segmentation_abs_or_delta_update = $buf->bit();
            $ret .= " segmentation_abs_or_delta_update=$segmentation_abs_or_delta_update";
            for (my $i = 0; $i < $::MAX_SEGMENTS; $i++) {
                for (my $j = 0; $j < $::SEG_LVL_MAX; $j++) {
                    my $feature_enabled = $buf->bit();
                    if ($feature_enabled == 1) {
                        my $bits_to_read = $::segmentation_feature_bits[$j];
                        my $feature_value = $buf->bits($bits_to_read);
                        if ($::segmentation_feature_signed[$j] == 1) {
                            my $feature_sign = $buf->bit();
                            if ($feature_sign == 1) {
                                $feature_value *= -1;
                            }
                        }
                        $ret .= " FeatureData[$i][$j]=$feature_value";
                    }
                }
            }
        }
    }

    return $ret;
}

sub read_prob($) {
   my ($buf) = @_;

   my $prob_coded = $buf->bit();

   if ($prob_coded == 1) {
       my $prob = $buf->bits(8);
       return "$prob";
   }
   else {
       return "(255)";
   }
}

while (<>) {
    if (/ *(.*) data=([a-z0-9]*)/) {
        my $header_desc = $1;
        my $payload = pack("H*", $2);

        my $buffer = new BitBuffer(buffer => $payload);

        my $payload_desc;
        try {
            $payload_desc = parse_payload($buffer);
        }
        catch {
            $payload_desc = "[Error parsing VP9 payload: $_]";
        };

        print "$header_desc\n\t$payload_desc\n";
    }
}
