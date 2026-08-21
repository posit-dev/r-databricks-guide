# Posit Public Package Manager, which serves pre-built binaries on Linux, so
# sf and arrow install in seconds rather than compiling from source. Keep the
# generic URL: renv detects the distribution and rewrites it to the matching
# binary path, so this stays correct on other images. Set before renv activates
# so renv::restore() and interactive install.packages() agree.
options(repos = c(CRAN = "https://p3m.dev/cran/latest"))

if (file.exists("renv/activate.R")) source("renv/activate.R")
