# A prototype QC pipeline in Snakemake and Singularity

## Running

Clone the appriate portion of the repository:

```console
git clone --depth 1 --no-checkout --filter=blob:none https://github.com/andersgs/playground.git proto_qc
cd proto_qc
git checkout master -- snakemake/qc_pipeline && cd snakemake/qc_pipeline
```

### Unix

Run `bash startup.sh`. This will download the singularity images, and a test dataset. Then, run `snakemake --use-singularity`. 
Assumes `snakemake` is installed and available.

### Mac

Install `vagrant` and `virtualbox`. I suggest using `brew`:

`brew cask install vagrant virtualbox`

Then, run:

`vagrant up` --- this will bootstrap the Ubuntu box with Singularity installed, and will download all the Singularity images.

Then, run:

`vagrant ssh` --- this will log you on to the Ubuntu box.

Then, run:

`cd qc_folder && snakemake --use-singularity`

## Elements

1. Raw stats and trimming
   1. `seqtk`
   2. `timmomatic` (could eventually use `fastp`)
2. Kmer genome size and optional subsampling
   1. `mash`
3. Species identification
   1. `kraken2` --- for this prototype I am only using the 8GB minikraken DB.
4. Assembly
   1. `spades`
   2. `shovill`
   3. `skesa`
5. Serotyping/Sequence Typing
   1. `mlst`
   2. Appropriate serotyping tool for the species (**not implemented**)
6. AMR detection
   1. `abricate`


## Structure

Rather than target inputs and outputs from the different tools, I took an approach of 
generating a `toml` formatted file that has all the information (see below for an 
example output). These `toml` files 
are then passed between rules. This simplifies the rule construction, and produces 
a single file at the end with all the information we would like to archive in a DB.

At the momement, the rules are structured in a dependency structure that enforces a 
linear run through the pipeline. In other words, a rule only depends on the previous
rule, and will only affect the next rule. This is not the most efficient approach,
as there are some rules that could all depend on a single step and thus be run in 
parallel. However, this approach allows one to incrementally build the `toml` file
rather than have to gather all the files at the end.

## Rules

### `read_assessment`

Generates basic stats on the reads. Takes as a `param` the `file_type`. At the
momemt, we have two file types: `raw` and `trimmed`. The idea is that the 
rule can be reused to generate the same stats from `trimmed` files. We will
see that below.

### `trim_reads`

Uses `trimmomatic` to trim the reads. Accepts the following `params`:

- `min_qual`: Minimum quality score (0-40)
- `file_type`: default `raw` --- one could eventually preprocess the reads before trimming

One can also set the `threads` directive, defaul 1.

### `trimmed_read_assessment`

Like `read_assessment` above, but on the trimmed reads.

### `run_kraken`

Run `kraken2` to perform kmer species identification. At the moment, the command
assumes `--paired` reads. This could become flexible to allow for single-end reads.
Accepts the following `params`:

- `file_type`: whether to use the `raw` or `trimmed` reads (default: `trimmed`)
- `kraken_opts`: a `str` with additional options to pass on to the `kraken` command.

One can also set the `threads` directive, default 2.

### `estimate_genome_size`

Run `mash sketch` to estimate genome size and expected coverage of the genome. 
Accepts the following `params`:

- `file_type`: which read set to use (`raw` or `trimmed`; default: `trimmed`)
- `min_kmer_count`: ignore `kmers` with `min_kmer_count` or fewer counts (default: 3)
- `kmer_len`: the lenght of kmers to count (default: 31)
- `mash_opts`: a `str` with additional options to pass on to `mash sketch`

### `assemble_reads`

Using one of `shovill`, `spades`, or `skesa` assemble the reads. The rule 
accepts as `params`:

- `assembler`: one of `shovill`, `spades`, or `skesa`
- `file_type`: which reads to use (`raw` or `trimmed`)
- `memory`: try to keep the RAM footprint to this level (in GB)
- `asm_opts`: a `str` to pass on to the assembler command

In addition, one can set the `threads` directive (default 2).

The current setup could be modified to allow for all three assemblers to be 
run in parallel using the same rule. One would have to modify the `input`
directive to accept the `assembler` as a wildcard. One would have to modify
the approach to allow for self-contained `toml` files per rule, and then a
gather function at the end to put them all together.

### `run_mlst`

Run `mlst` on the assembled contigs. 
Accepts as parameters:

- `assembler`: to specify which assembly to use
- `mlst_opts`: a `str` to pass on to the `mlst` command with additional options.

### `run_amr`

Run `abricate` on the assembled contigs.
Accepts as parameters:

- `assembler`: to specify which assembly to use
- `db`: to specify which DB to use
- `abricate_opts`: a `str` to pass on additional options to the `abricate` command.

### `gather_toml`

A rule that will eventually act to gather all the `toml` files from individual steps
into a single `toml` for a sample.

## Example `toml` output

```toml
[ERR1305793.kraken]
unclassified = 2.23
[[ERR1305793.kraken.classified]]
percentage = 93.5
taxon = "Salmonella"

[ERR1305793.kraken.classified.species]
percentage = "91.3"
taxon = "Salmonella enterica"
[[ERR1305793.kraken.classified]]
percentage = 0.12
taxon = "Enterococcus"

[ERR1305793.kraken.classified.species]
percentage = "0.11"
taxon = "Enterococcus faecium"
[[ERR1305793.kraken.classified]]
percentage = 0.01
taxon = "Citrobacter"

[ERR1305793.kraken.classified.species]
percentage = "0.0"
taxon = "Citrobacter freundii"

[ERR1305793.mash]
genome_size = 4970990.0
coverage_estimate = 40.43
from_reads = "trimmed"

[ERR1305793.shovill]
file_type = "trimmed"
contigs = "ERR1305793/shovill.fasta"

[ERR1305793.mlst]
scheme = "senterica"
st = "19"
alleles = [ "aroC(10)", "dnaN(7)", "hemD(12)", "hisD(9)", "purE(5)", "sucA(9)", "thrA(2)",]
assembler = "shovill"
contigs = "ERR1305793/shovill.fasta"

[ERR1305793.abricate]
assembler = "shovill"
db = "ncbi"
contigs = "ERR1305793/shovill.fasta"
results = ""

[ERR1305793.files.raw."ERR1305793/R1.fq.gz"]
filename = "ERR1305793/R1.fq.gz"

[ERR1305793.files.raw."ERR1305793/R2.fq.gz"]
filename = "ERR1305793/R2.fq.gz"

[ERR1305793.files.trimmed."ERR1305793/R1_trim.fq.gz"]
filename = "ERR1305793/R1_trim.fq.gz"

[ERR1305793.files.trimmed."ERR1305793/R2_trim.fq.gz"]
filename = "ERR1305793/R2_trim.fq.gz"

[ERR1305793.files.raw."ERR1305793/R1.fq.gz".summary]
min_len = 35.0
max_len = 301.0
avg_len = 199.37
distinct_error_codes = 33
bases = 193104534.0
A = 23.8
C = 26.2
G = 26.3
T = 23.6
N = 0.1
avgQ = 36.2
errQ = 25.6
low = 2.6
high = 97.40000000000001
total_reads = 968585.0
geecee = 52.5
med_len = 202.0

[ERR1305793.files.raw."ERR1305793/R2.fq.gz".summary]
min_len = 35.0
max_len = 301.0
avg_len = 205.92
distinct_error_codes = 33
bases = 199455461.0
A = 24.3
C = 28.4
G = 24.9
T = 22.4
N = 0.1
avgQ = 29.7
errQ = 16.2
low = 22.3
high = 77.7
total_reads = 968585.0
geecee = 53.3
med_len = 212.0

[ERR1305793.files.trimmed."ERR1305793/R1_trim.fq.gz".summary]
min_len = 36.0
max_len = 301.0
avg_len = 181.18
distinct_error_codes = 33
bases = 143079111.0
A = 23.9
C = 26.1
G = 26.2
T = 23.8
N = 0.0
avgQ = 37.2
errQ = 33.0
low = 0.4
high = 99.59999999999999
total_reads = 789690.0
geecee = 52.3
med_len = 173.0

[ERR1305793.files.trimmed."ERR1305793/R2_trim.fq.gz".summary]
min_len = 36.0
max_len = 301.0
avg_len = 137.87
distinct_error_codes = 33
bases = 108877495.0
A = 24.0
C = 26.1
G = 25.9
T = 24.0
N = 0.0
avgQ = 36.3
errQ = 28.5
low = 1.3
high = 98.7
total_reads = 789690.0
geecee = 52.0
med_len = 139.0
```