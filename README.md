## PredDNAContam is a tool to Estimate Within-Species DNA Contamination.

### What is Within-Species DNA Contamination?
##### Within-species DNA contamination occurs when DNA from the same species (e.g., human DNA in a human sample) accidentally ends up in the sample. This can occur during sample collection, preparation, or sequencing. Accurately measuring contamination is important for genetic studies, especially in areas like rare disease research, where accurate  detection of variants is essential.

### Data
- ##### **Source**: Human blood samples.
- ##### Sample Size: A total of 4,400 samples were used, consisting of:
  * ###### 400 uncontaminated patient samples (0% contamination).
  * ###### 4,000 contaminated in-silico samples, generated using thirty CRAM files from uncontaminated patient samples.
    ###### The contamination was simulated at 10 different levels: 3%, 5%, 10%, 15%, 20%, 25%, 30%, 35%, 40%, and 45%.
 


### More Details on Model Development

##### For a detailed explanation of how the model was built—including all the steps in generating the in-silico training data and the full modeling process please see the [Wiki](https://github.com/razmo63/PredDNAContam/wiki).

### Installation of PredDNAContam Tool

##### To install and run the PredDNAContam tool, visit [PyPI](https://pypi.org/project/PredDNAContam/) and follow the instructions in the README file.


### Project Affiliation
##### This project was conducted at Clinical Genomics, SciLifeLab in Stockholm, under the supervision of Peter Pruisscher.
