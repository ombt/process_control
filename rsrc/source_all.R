#
# load any rlib functions.
#
if (Sys.getenv("OMBT_ANALYTICS_BASE") != "")
{
    #
    # generic utils
    #
    source(paste(Sys.getenv("OMBT_ANALYTICS_BASE"),
                 "rlib",
                 "generic_utils.R",
                 sep="/"))
    #
    # loading package utils
    #
    source(paste(Sys.getenv("OMBT_ANALYTICS_BASE"),
                 "rlib",
                 "package_utils.R",
                 sep="/"))
    #
    # sqlite db utils
    #
    source(paste(Sys.getenv("OMBT_ANALYTICS_BASE"),
                 "rlib",
                 "sqlite_utils.R",
                 sep="/"))
    #
    # loading csv file utils
    #
    source(paste(Sys.getenv("OMBT_ANALYTICS_BASE"),
                 "rlib",
                 "csv_utils.R",
                 sep="/"))
    #
    # loading u0x db utils
    #
    source(paste(Sys.getenv("OMBT_ANALYTICS_BASE"),
                 "rlib",
                 "u0x_sqlite_utils.R",
                 sep="/"))
}
#
# local loading data from db or csv
#
if (file.exists("load_data.R"))
{
    source("load_data.R")
}
#
