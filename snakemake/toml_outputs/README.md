# A Snakemake approach to facilitate QC pipelines

## Proposal

Often in QC pipelines, we need to keep information from each
step. Outputs from each step may be dynamic too, depending on
what data comes in to the pipeline (e.g., mixed single/paired end reads,
illumina/ion torrent, trimming, etc.), what options are included
in each step, and the needs for each sample (e.g., serotyping,
etc.). This poses a problem for something like Snakemake that requires
predictable inputs and outputs from each step.

One possible solution is to encode information at each step in a TOML
file that becomes the output from a rule, and the input to the next rule.
The problem with this approach is that you can end up an n number of
extra files. Ideally, there would be single TOML file that just gets
updated in each step. This is not a feature that Snakemake supports.
However, it is possible to get around this restriction by using `temp`
just renaming the TOML file at each step.

In this approach, all the information needed for subsequent steps are
encoded in the TOML file. Within each rule, one would decode the TOML
file, and the rule would include logic for what needs to be done to
based on the information encoded in the TOML file. Before the rule ends,
it adds new information to the TOML file and saves it with the new name.

This approach greatly simplifies the input and output directives of each
rule, allows one to encode rich information for each step in the TOML
format that can enable tracibility, high quality evaluation
of the data, and easy injection in to a database.

Here, I demonstrate how this would work. To run it, clone the repository,
make sure you have `Snakemake` version ≥5.4 installed, cd in to the
folder, and run `snakemake`.
