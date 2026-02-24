#!/usr/bin/env python3

import sys

input_dir = "/data/Haystack/for-thomas-arcila-notpublic"
spp = 1

inputs = {
    "headlight": f"{input_dir}/embree-headlight.mini {input_dir}/hdr-symmetrical-garden.mini -spp {spp} --camera -753.732 517.383 -655.327 -315.048 234.48 -451.202 0 1 0 -fovy 60",
    "e89-open": f"{input_dir}/embree-e89_open.mini {input_dir}/hdr-symmetrical-garden.mini  -spp {spp} --camera -4463.85 1730.73 -3772.79 -781.03 -737.24 544.526 0 1 0 -fovy 60",
    "e89-closed": f"{input_dir}/embree-e89_closed.mini {input_dir}/hdr-symmetrical-garden.mini -spp {spp} --camera -3397.79 1100.48 -3555.56 -1160.79 -837.692 803.035 0 1 0 -fovy 60",
    "vasculature": f"{input_dir}/vasculature.caps {input_dir}/hdr-symmetrical-garden.mini -os 1600 1200 -spp {spp} --camera -392.211 1474.32 2397.24 747.827 553.862 1079.22 0 1 0 -fovy 60",
    "ls": f"{input_dir}/ls.mini -os 2460 1080 -spp {spp} --camera -2976.901123 309.4327087 -3735.08252 1474.776611 1074.60376 4633.866699 0 1 0 -fovy 70",
}

if len(sys.argv) > 1:
    print(inputs[sys.argv[1]])
