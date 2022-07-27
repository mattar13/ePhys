# ePhys


This is a project for opening electrophysiology/engineering data in Julia. 

This package will utilize many different sources for it's data. Each file format will gets its own package. 

To Do list: 
- [ ] Make a Pluto.jl data entry suite to use as analysis GUI
- [ ] Open .mat files (For use with MatLab and Symphony)
- [ ] Open .idata files (For use with MatLab and IrisData https://github.com/sampath-lab-ucla/IrisDVA)
- [ ] Open .csv files (Some formats are saved as CSV files, especially from LabView products)
- [ ]

Completed Tasks: 
- [x] Move Experiment.jl and the associated files with it
- [x] Open .abf files (ABFReader.jl)
- [x] Move Datasheet functions into the package
- [x] Move Plotting functions into the package

