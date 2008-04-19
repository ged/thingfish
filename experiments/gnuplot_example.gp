
set terminal png size '800x600' x000000 xffffff x444444
set output 'graph.png'

set title "ThingFish Benchmark\n500 Requests, 5 concurrent -- GET /"
set grid x y
set xlabel "Total time: 2.682109 seconds\n186.42 Requests/sec, 27.396 ms average"
set ylabel 'Time (ms)'
set key top left horizontal
set key box width 2
set yrange [0:]
set format y "%5.0f"

plot 'tf-get-root.tsv' using 0:8 title "dtime" with lines linecolor rgb "#94c2b3", \
     'tf-get-root.tsv' using 0:9 title "ttime" with lines linecolor rgb "#f0eac4", \
     'tf-get-root.tsv' using 0:10 title "wait" with lines smooth bezier linewidth 3 linecolor rgb "#c8cbee"

