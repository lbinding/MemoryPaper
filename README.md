# Software and Analysis for Direct and Indirect Routes of Memory Function

Thank you for visiting this GitHub page! This repository contains the code necessary to replicate the results presented in our paper. Our analysis is implemented in R, while the software for reconstructing fiber bundles—called Anatomically Targeted Automated Tractography (AT-AT)—is developed using Bash.

## AT-AT

A description of this software can be found in the paper:

### 7T White Matter Anatomical Priors

The Geodesic Information Flow (GIF) parcellation was utilized to extract cortical regions, serving as seed and termination points for tractography. Anatomically constrained tractography, using hybrid surface and volume segmentation in MRtrix3, was performed with a second-order integration over the fiber orientation distribution probabilistic fiber tracking algorithm. This method selects a maximum of 5000 streamlines from 300 million seeds. Tractography was performed twice, switching the seed and termination cortical ROIs. 

The fiber bundles were then converted to probabilistic maps, thresholded at a value of 0.01, which served as an exclusion criterion to remove spurious streamlines. The cleaned tractograms were transformed to MNI space, converted to binary masks, and dilated by 1 mm to account for co-registration errors. Each fiber bundle was manually inspected to ensure accurate reconstruction, and manual exclusion masks were used to eliminate any spurious streamlines.

### Tractography in Subjects

To reconstruct the fiber bundles of interest, masks constructed from the MNI Human Connectome Project 7T data were transformed to patient-native space using EasyReg. The same cortical regions and tractography parameters that were used to create the anatomical priors were applied in this reconstruction, with the 7T anatomical priors serving as an inclusive mask. Any streamlines exiting the mask were discarded, and each fiber bundle was manually inspected for accuracy.

### Requirements

To run this software, you will need the following:
- **FreeSurfer 7.4 or above**
- **MRtrix3**
- **FSL**
- **Nibabel** (Python package)

After cloning this repository, you can execute the script using your terminal, for example:

```bash
/Users/lbinding/MemoryPaper/AT-ATv2/scripts/ATATv2_vCing.sh
```

Running this script will provide you with instructions on what files you need to input. The available options for input are as follows:

- `-gif`:          Input GIF parcellation — **REQUIRED**
- `-T1`:           Input T1 parcellation — **REQUIRED**
- `-fivett`:       Input 5tt image — **REQUIRED**
- `-FOD`:          Input CSD image — **REQUIRED**
- `-out`:          Output folder for tracts — **REQUIRED**
- `-roi_dir`:      Output folder for tract ROIs — **REQUIRED**
- `-niftyReg`:     Use NiftyReg registration tract mask — **OPTIONAL**
- `-alg`:          Select default algorithm: `det` or `prob` (default=`prob`) — **OPTIONAL**

### Atlas-Based Disconnection
The reconstruction of these fibre bundles in Temporal Lobe Epilepsy is found in `AtlasBasedTracts`. You can use these in combination with `Tractotron` to reproduce our atlas-based analysis.

## Analysis 
The analysis and code can be found in `Final_Analysis_Cleaned_public.Rmd`. This is an R Markdown notebook that can be used to reproduce the findings. While we cannot provide tabular data here, you may request access by emailing: [lawrence.binding.19@ucl.ac.uk](mailto:lawrence.binding.19@ucl.ac.uk).





