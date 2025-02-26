import pysam
import pandas as pd
import os
import matplotlib.pyplot as plt
import seaborn as sns
import sys

# Check if the correct number of arguments is provided
if len(sys.argv) != 3:
    print("Usage: python script.py <input_vcf_file> <output_directory>")
    sys.exit(1)

# Get the VCF file path and output directory from command line arguments
vcf_file_path = sys.argv[1]
output_dir = sys.argv[2]
os.makedirs(output_dir, exist_ok=True)

### Function to plot VAF distribution
def plot_vaf_distribution(heterozygous_sites, output_dir, vcf_file_name):
    vaf_values = [site["VAF"] for site in heterozygous_sites]
    
    if vaf_values:
        plt.figure(figsize=(10, 6))
        sns.histplot(vaf_values, bins=50, kde=True, color='blue', edgecolor='black')
        plt.axvline(0.5, color='red', linestyle='--', label='Expected VAF (0.5)')
        plt.title(f'VAF Distribution for Heterozygous Sites ({vcf_file_name})')
        plt.xlabel('VAF (Variant Allele Frequency)')
        plt.ylabel('Frequency')
        plt.legend(title='Legend')
        plt.tight_layout()
        plot_filename = os.path.join(output_dir, f"{vcf_file_name}_vaf_distribution.png")
        plt.savefig(plot_filename)
        plt.close()
        print(f"VAF distribution plot saved for {vcf_file_name}.")
    else:
        print(f"No heterozygous sites found for VAF plot in {vcf_file_name}.")

### Main function to process the VCF file
def process_vcf(vcf_file_path, output_dir):
    vcf_file_name = os.path.splitext(os.path.basename(vcf_file_path))[0]
    vcf_in = pysam.VariantFile(vcf_file_path, "r")

    data = []
    heterozygous_sites = []

    # Iterate through each record in the VCF file
    for record in vcf_in:
        chrom = record.chrom
        pos = record.pos
        ref = record.ref
        alt = record.alts[0]  # Assuming bi-allelic variants
        gt = record.samples[0]["GT"]  # Genotype (GT) field
        gq = record.samples[0]["GQ"]  # Genotype Quality (GQ) field
        ad = record.samples[0]["AD"]  # Allelic Depths (AD) field
        dp = record.info.get("DP")  # Total Read Depth (INFO field)
        #dp = record.samples[0]["DP"]  based on VCF file can be changed, in some DP are in info and some in format field

        af = record.info["AF"][0] if "AF" in record.info else None  # Allele Frequency (AF)

        # Calculate VAF
        if dp and dp > 0:
            vaf = round(sum(ad[1:]) / dp, 2) if ad and len(ad) > 1 else 0.0
        else:
            vaf = 0.0

        # Identify heterozygous sites (GT != hom-ref, e.g., 0/1, 1/2, etc.)
        if gt and len(gt) == 2 and gt[0] != gt[1]:  # Heterozygous condition
            heterozygous_sites.append({"VAF": vaf, "CHROM": chrom, "POS": pos, "REF": ref, "ALT": alt})
        
        # Store data
        data.append({
            "CHROM": chrom,
            "POS": pos,
            "REF": ref,
            "ALT": alt,
            "GT": gt,
            "GQ": gq,
            "AD": ad,
            "DP": dp,
            "AF": af,
            "VAF": vaf
        })

    # Save detailed CSV file
    df = pd.DataFrame(data)
    detailed_csv_name = os.path.join(output_dir, f"{vcf_file_name}.csv")
    df.to_csv(detailed_csv_name, index=False)
    print(f"CSV file saved for {vcf_file_path}")

    # Plot VAF distribution for heterozygous sites
    plot_vaf_distribution(heterozygous_sites, output_dir, vcf_file_name)

# Run the process
process_vcf(vcf_file_path, output_dir)