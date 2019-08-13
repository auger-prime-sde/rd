
fft's take a relatively large amount of time to compute. So I made those incremental and saved the fft'ed data to separate files in the ffts directory. The procedure to reproduce waterfall plot:

1) rsync -auv "pi@augerpi1:data/*.npy" data
(Alternatively, if using ssh forwarding to tunnel into the pi: rsync -auve "ssh -p 2222" "pi@augerpi1:data/*.npy" data)
Above stopped working with many files. Try instead:
ssh pi@augerpi1 'find data -type f' >! npyfiles.txt
rsync -auv --files-from npyfiles.txt pi@augerpi1: data


2) run the fft script: python3 updateffts.py (running it again later should quickly skip the traces that were already processed)

3) run the imaging script: python3 waterfall.py




analysis.py is old and relies on a different data layout. It was used to produce movies. It requires an images directory to write to and possibly also expects data in a different location. With minimal patching that should be possible to get working again.
