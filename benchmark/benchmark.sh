#!/bin/bash
# run from top-level directory(lua-db/)
strides="128" # list of strides that are tested
threads="6" # list of thread counts that are tested
methods="simple" # list of test methods only supporting the threads argument
methods_stride="ffi ffi_shared_buf" # list of test methods supporting the stride argument
sdfs="sdf_basic.lua sdf_simple.lua"
test_preview=true # run the render a preview using multithread_pixel_function_render.lua test
preview_size="640" # size for multithread_pixel_function_render.lua test
benchmark=true # run the multithread_pixel_function_benchmark.lua test
generate_svg=true # generate the svg graphs using json_to_svg.lua
svg_width="700"
svg_height="700"
generate_html=true # generate the benchmark.html file
outdir="./benchmark/results/$(date +"%d-%m-%Y_%T")"
json_to_svg="./benchmark/json_to_svg.lua"
mkdir -p $outdir

echo "benchmark output directory ${outdir}"

# run "simple" tests(not using stride)
for SDF in $sdfs; do
	for METHOD in $methods; do
		for THREAD in $threads; do
			echo "Testing SDF: ${SDF}, Method: ${METHOD}, Threads: ${THREAD}"

			if $test_preview; then
				echo "Running preview..."
				time luajit ./examples/multithread_pixel_function_render.lua \
				--render_width=${preview_size} --render_height=${preview_size} \
				--preview_scale=0.2 \
				--duration=3 --render_fps=30 \
				--sdf="./examples/data/${SDF}" \
				--rawfile= \
				--log=stdout \
				--method=${METHOD} --threads=${THREAD}
			fi

			if $benchmark; then
				luajit ./examples/multithread_pixel_function_benchmark.lua \
				--json=${outdir}/${SDF}_${METHOD}_${THREAD}t.json \
				--sdf="./examples/data/${SDF}" \
				--log=stdout \
				--method=${METHOD} --threads=${THREAD}
			fi
		done
	done
done

# run stride tests
for SDF in $sdfs; do
	for METHOD in $methods_stride; do
		for STRIDE in $strides; do
			for THREAD in $threads; do
				echo "Testing SDF: ${SDF}, Method: ${METHOD}, Threads: ${THREAD}, Stride: ${STRIDE}"

				if $test_preview; then
					echo "Running preview..."
					time luajit ./examples/multithread_pixel_function_render.lua \
					--render_width=${preview_size} --render_height=${preview_size} \
					--preview_scale=0.2 \
					--duration=3 --render_fps=30 \
					--sdf="./examples/data/${SDF}" \
					--rawfile= \
					--log=stdout \
					--method=${METHOD} --threads=${THREAD} --stride=${STRIDE}
				fi

				if $benchmark; then
					luajit ./examples/multithread_pixel_function_benchmark.lua \
					--json=${outdir}/${SDF}_${METHOD}_${THREAD}t_${STRIDE}s.json \
					--sdf="./examples/data/${SDF}" \
					--log=stdout \
					--method=${METHOD} --threads=${THREAD} --stride=${STRIDE}
				fi
			done
		done
	done
done


if $generate_svg; then
	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=avg \
	--xformat="%dpx" --yformat="%.2fms" \
	--xunit=1 --yunit=1000 \
	${outdir}/*.json > ${outdir}/avg.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=min \
	--xformat="%dpx" --yformat="%.2fms" \
	--xunit=1 --yunit=1000 \
	${outdir}/*.json > ${outdir}/min.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=max \
	--xformat="%dpx" --yformat="%.2fms" \
	--xunit=1 --yunit=1000 \
	${outdir}/*.json > ${outdir}/max.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=total \
	--xformat="%dpx" --yformat="%.2fs" \
	--xunit=1 --yunit=1 \
	${outdir}/*.json > ${outdir}/total.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=mb_per_second \
	--xformat="%dpx" --yformat="%dMB/s" \
	--xunit=1 --yunit=1 \
	${outdir}/*.json > ${outdir}/mbps.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=per_px \
	--xformat="%dpx" --yformat="%.2fns/px" \
	--xunit=1 --yunit=1000000000 \
	${outdir}/*.json > ${outdir}/per_px.svg

	$json_to_svg \
	--width=${svg_width} --height=${svg_height} \
	--xvar=w --yvar=dmem \
	--xformat="%dpx" --yformat="%dkb" \
	--xunit=1 --yunit=1 \
	${outdir}/*.json > ${outdir}/dmem.svg
fi


if $generate_html; then
	cat << EOF > ${outdir}/benchmark.html
<!DOCTYPE html>
<html>
	<head>
		<meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
	</head>
	<body style="margin: 0 0; padding: 0 0;">
		<div style="max-width: ${SVG_WIDTH}px; margin: 0 auto; padding: 50px 50px; box-sizing: border-box;">
EOF

	while read i; do
		echo "<h1>$(basename -s .svg $i)</h1>" >> ${outdir}/benchmark.html
		echo "<img src=\"$(basename $i)\" width=$SVG_WIDTH height=$SVG_HEIGHT>" >> ${outdir}/benchmark.html
		echo "<hr>" >> ${outdir}/benchmark.html
	done < <(ls -rt ${outdir}/*.svg)

cat << EOF >> ${outdir}/benchmark.html
		</div>
	</body>
</html>
EOF
fi
