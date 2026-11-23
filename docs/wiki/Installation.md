> 🌐 **English** · [Deutsch](de/Installation.md)

# Installation

You only need to do this **once**. Afterwards jellyqda runs without internet.

## 1. Install R and RStudio (if you do not have them yet)

- **R** (version 4.0 or newer): <https://cran.r-project.org>
- **RStudio** (recommended, but not required): <https://posit.co/download/rstudio-desktop/>

Both are free and run on Windows, macOS and Linux.

## 2. Install jellyqda: one line

Open RStudio (or R) and paste into the **console**:

```r
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")
```

The script works through five steps and shows what happens (in English, or
in German on a German system):

```
[1/5] Check the R version
   OK   R 4.4.1
[2/5] Check the required packages
   ..   installing 2 package(s): shiny, bslib
[3/5] Install jellyqda
   OK   jellyqda 0.7.0 installed
[4/5] Check the installation
   OK    app files (CSS/JS)
   OK    undo/redo
   ...
[5/5] Done! Next steps:
```

The first time, step 2 can take a few minutes.

## Other ways

```r
# from a downloaded ZIP file:
options(jellyqda.install.path = "~/Downloads/jellyqda.zip")
source("https://raw.githubusercontent.com/thedivingshellyfish/jellyqda/main/install_jellyqda.R")

# install a particular branch or tag:
options(jellyqda.install.ref = "main")

# start a demo right after the installation:
options(jellyqda.install.start_app = TRUE)
```

You can also download the script, open it in RStudio and click **"Source"**.

## Linux: system libraries

For PDF and Word import R needs a few system libraries on Linux, once. If
they are missing, the installation script names the right command for your
distribution, e.g. for Ubuntu/Debian (in a **terminal**, not in R):

```bash
sudo apt install libpoppler-cpp-dev libxml2-dev libssl-dev libcurl4-openssl-dev libfontconfig1-dev
```

Then simply run the script again.

## Updating

Run the same line as above again. An old version that is already loaded is
unloaded automatically; in RStudio, to be safe, use **Session → Restart R**
afterwards.

> ⚠️ Before opening an existing project with a new version for the first time:
> create a `qda_backup()` (with the old version).

Next: **[First steps](First-steps.md)**
