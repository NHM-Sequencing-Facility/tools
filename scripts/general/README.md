# General bioinformatics scripts

Scripts for miscellaneous bioinformatics tasks, such as compression and decompression of data.

### comress.sh
```

```


### decompress.sh
```
Decompress and extract a .tar.gz archive on the HPC using multi-threaded
pigz, keeping the original archive.

  1. Decompress the .tar.gz to an intermediate .tar (pigz, 8 threads)
  2. Extract the .tar into the same directory as the input archive
  3. Remove the intermediate .tar after decompression

Requirements:
  - Conda environment with pigz (archive)
  - Free disk space for both the intermediate .tar and the extracted
    contents alongside the original archive

Input:
  - Absolute path to a .tar.gz archive (INPUT_ARCHIVE)

Main outputs (in the input archive's directory):
  - Extracted archive contents
  - Original .tar.gz is kept (pigz -k)
  - SLURM logs: decompress_<jobid>.out, decompress_<jobid>.err

Usage:
  Set INPUT_ARCHIVE to the absolute path of the archive, then:
  sbatch decompress.sh

version: 1.0
```
