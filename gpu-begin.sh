qsub -I -l procs=5,tpn=5,mem=40gb,walltime=1:00:00 -q cpsc424gpu
~ahs3/bin/gpuget 
cat .cpsc424gpu
~ahs3/bin/gpulist
module load Langs/Intel/15 GPU/Cuda/8.0
deviceQuery

