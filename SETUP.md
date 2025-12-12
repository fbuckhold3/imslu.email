# Initial Setup Instructions

## First-Time Setup (Run Locally)

Since R is not available in this environment, you'll need to initialize `renv` on your local machine.

### Step 1: Initialize renv

Open R or RStudio in this project directory and run:

```r
# Install renv if you don't have it
install.packages("renv")

# Initialize renv for this project
renv::init()

# Install required packages
install.packages(c(
  "httr",      # REDCap API calls
  "dplyr",     # Data manipulation
  "ggplot2",   # Visualizations
  "knitr",     # Tables
  "quarto"     # Document rendering
))

# Snapshot the dependencies
renv::snapshot()
```

### Step 2: Setup Environment Variables

```bash
cp .Renviron.example .Renviron
```

Edit `.Renviron` with your actual REDCap tokens.

### Step 3: Test Locally

```r
quarto::quarto_render("weekly_report.qmd")
```

### Step 4: Commit and Push

Once everything works locally:

```bash
git add .
git commit -m "Initialize renv and setup project"
git push origin main
```

Then proceed with Posit Connect deployment per README.md instructions.

## If renv is Already Initialized

If you're cloning this repo after renv has been set up:

```r
# Restore packages from lockfile
renv::restore()
```
