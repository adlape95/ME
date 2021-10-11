#!/bin/bash

##SCRIPTS##

##Activate conda environment
conda activate qiime2-2020.8

# Create a Manifest (in-house script)
qiime2input-MEall.py -i /media/darwin/c416f3d9-3986-47fd-b7ea-5f73aae3a518/Proyectos/2019-39yTu-16S/all_fastq/ > Manifest

##Import demultipliex sequences through Manifest file
qiime tools import \
  --type 'SampleData[PairedEndSequencesWithQuality]' \
  --input-path Manifest \
  --output-path ./demux-paired-end.qza \
  --input-format PairedEndFastqManifestPhred33

## Check parameters of the reads
qiime demux summarize \
  --i-data ./demux-paired-end.qza \
  --o-visualization ./demux-paired-end.qzv


###########
## DADA2 ##
###########

####################################
## DADA2 (separating 250 and 300) ##
####################################

## It is VERY important to process the 2x250bp and the 2x300bp reads in batches

############
## 250 bp ##
############

## Import sequences and create summary done as usual (see above)
## DADA2 (removing barcodes)

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs ./demux-paired-end.qza \
  --verbose \
  --p-trim-left-f 17 \
  --p-trim-left-r 21 \
  --p-trunc-len-f 245 \
  --p-trunc-len-r 245 \
  --p-n-threads 8 \
  --o-table ./table.qza \
  --o-representative-sequences ./rep-seqs.qza \
  --o-denoising-stats ./denoising-stats.qza


############
## 300 bp ##
############

## Import sequences and create summary done as usual (see above)
## DADA2 (removing barcodes)
## Use the same parameters to merge the results a posteriori.

qiime dada2 denoise-paired \
  --i-demultiplexed-seqs ./demux-paired-end.qza \
  --verbose \
  --p-trim-left-f 17 \
  --p-trim-left-r 21 \
  --p-trunc-len-f 245 \
  --p-trunc-len-r 245 \
  --p-n-threads 12 \
  --o-table ./table.qza \
  --o-representative-sequences ./rep-seqs.qza \
  --o-denoising-stats ./denoising-stats.qza

#########################
## MERGING 250 and 300 ##
#########################

## https://docs.qiime2.org/2020.8/tutorials/fmt/
## 1st: merge tables

qiime feature-table merge \
  --i-tables table-250bp.qza \
  --i-tables table-300bp.qza \
  --o-merged-table table-all.qza

## 2nd: merge rep-seqs

qiime feature-table merge-seqs \
  --i-data rep-seqs-250bp.qza \
  --i-data rep-seqs-300bp.qza \
  --o-merged-data rep-seqs-all.qza

## 3rd: statistics after merging

qiime feature-table summarize \
  --i-table table-all.qza \
  --o-visualization table-all.qzv

####################
## CLASSIFICATION ##
####################

##Taxonomic classification. Database SILVA 132.
qiime feature-classifier classify-sklearn \
  --i-classifier /media/darwin/c416f3d9-3986-47fd-b7ea-5f73aae3a518/Databases/silva-138-99-nb-classifier-2020-08.qza \
  --i-reads ./rep-seqs-all.qza \
  --verbose \
  --p-n-jobs 8 \
  --o-classification ./taxonomy.qza


################
## FORMATTING ##
################

##Export the qiime2 BiomTables (table.qza, taxonomy.qza, rooted-tree.qza) in such a way that it can be loaded into the R package phyloseq.

#Export table.qza and taxonomy.qza
qiime tools export \
 --input-path ./table-all.qza \
  --output-path  ./table

#Export taxonomy.qza and taxonomy.qza
qiime tools export \
 --input-path ./taxonomy.qza \
  --output-path  ./taxonomy


#Modify the biom-taxonomy tsv headers: change header "Feature ID" to "#OTUID"; "Taxon" to "taxonomy"; and "Confidence" to "confidence"
sed -i -e 's/Feature ID/#OTUID/g' ./taxonomy/taxonomy.tsv
sed -i -e 's/Taxon/taxonomy/g' ./taxonomy/taxonomy.tsv
sed -i -e 's/Confidence/confidence/g' ./taxonomy/taxonomy.tsv

#Add taxonomy data to .biom file
biom add-metadata -i ./table/feature-table.biom -o ./table-with-taxonomy.biom --observation-metadata-fp ./taxonomy/taxonomy.tsv --sc-separated taxonomy

#convert to json format
biom convert -i ./table-with-taxonomy.biom -o ./table-with-taxonomy-json2.biom --table-type="OTU table" --to-json

## THE END

