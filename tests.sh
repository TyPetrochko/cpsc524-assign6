./kij 1024 1024 1024 16 64  `cat ../.cpsc424_gpu` > task1_run1.txt
./kij 8192 8192 8192 32 256 `cat ../.cpsc424_gpu` > task1_run2.txt
./kij 1024 1024 8192 32 32  `cat ../.cpsc424_gpu`    > task1_run3.txt
./kij 8192 8192 1024 16 512  `cat ../.cpsc424_gpu`   > task1_run4.txt
./kij 8192 1024 8192 16 512  `cat ../.cpsc424_gpu`   > task1_run5.txt

# After changing the precision to double, run the following line
# ./kij 8192 8192 8192 32 256 `cat ../.cpsc424_gpu` > task1_b.txt

# For the following - use block size = 16 for all!
./tiled 1024 1024 1024 16 64  `cat ../.cpsc424_gpu`  > task2_run1.txt
./tiled 8192 8192 8192 16 512 `cat ../.cpsc424_gpu`  > task2_run2.txt
./tiled 1024 1024 8192 16 64  `cat ../.cpsc424_gpu`  > task2_run3.txt
./tiled 8192 8192 1024 16 512  `cat ../.cpsc424_gpu` > task2_run4.txt
./tiled 8192 1024 8192 16 512  `cat ../.cpsc424_gpu` > task2_run5.txt

# After changing the precision to double, run the following line
# ./tiled 8192 8192 8192 16 512 `cat ../.cpsc424_gpu`  > task2_b.txt

# For the following - block size of 16, tilesize of 2
./adjacent 8192 8192 8192 16 512 `cat ../.cpsc424_gpu` > task3.txt

