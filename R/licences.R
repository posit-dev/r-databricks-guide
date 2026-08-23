# The credit lines, in one place, worded exactly.
#
#   source("R/licences.R")
#
# Two licences, and they are different. Getting either wrong is a licensing
# error rather than a typo, so the wording lives here once and every page that
# shows data pulls from it rather than retyping it.
#
# A reader copying a figure into a paper is copying these lines with it.

# Environment Agency hydrology, stations, catchments and bathing waters.
WQ_LICENCE_OGL <- paste(
  "Contains Environment Agency information (c) Environment Agency and/or",
  "database right, licensed under the Open Government Licence v3.0."
)

# Storm overflow locations. CC BY 4.0, NOT OGL, and operational rather than
# regulatory data. The distinction is the water companies', not ours to blur.
WQ_LICENCE_CCBY <- paste(
  "Storm overflow outfall locations (c) the water companies, licensed under",
  "CC BY 4.0 and published via Stream / Water UK's National Storm Overflow",
  "Hub. Operational data: accuracy and completeness are disclaimed."
)

# OS Open Rivers, only where the river network is used.
WQ_LICENCE_OS <- "Contains OS data (c) Crown Copyright and database rights 2026."

#' Both lines that apply to everything in the worked example, as one string.
wq_credit <- function(include_os = FALSE) {
  parts <- c(WQ_LICENCE_OGL, WQ_LICENCE_CCBY)
  if (include_os) parts <- c(parts, WQ_LICENCE_OS)
  paste(parts, collapse = " ")
}
