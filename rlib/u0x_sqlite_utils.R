#
# common sections
#
# FID_DATA
# FILENAME_TO_IDS
# Index
# Information
#
# u01 sections
#
# CycleTime
# Count
# Time
# MountPickupFeeder
# MountPickupNozzle
# InspectionData
#
# u03 sections
#
# BRecg
# HeightCorrect
# MountExchangeReel
# MountLatestReel
# MountQualityTrace
# MountNormalTrace
#

sqlite_load_u01 <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("FILENAME_TO_IDS",
             "InspectionData",
             "MountPickupFeeder",
             "Count",
             "MountPickupNozzle",
             "CycleTime",
             "Index",
             "FID_DATA",
             "Information",
             "Time")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}

sqlite_load_nv_u01 <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("FILENAME_TO_IDS",
             "MountPickupFeeder",
             "MountPickupNozzle",
             "FID_DATA")
    #
    nv_tbls = c("InspectionData",
                "Count",
                "CycleTime",
                "Index",
                "Information",
                "Time")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading NON-NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    for (tbl in nv_tbls)
    {
        print(paste("reading NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_nv_table_from_db(db,
                                                   tbl,
                                                   nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}

sqlite_load_u03 <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("BRecg",
             "FILENAME_TO_IDS",
             "HeightCorrect",
             "MountExchangeReel",
             "Index",
             "MountLatestReel",
             "MountQualityTrace",
             "FID_DATA",
             "Information",
             "MountNormalTrace")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}

sqlite_load_nv_u03 <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("BRecg",
             "FILENAME_TO_IDS",
             "HeightCorrect",
             "MountExchangeReel",
             "MountLatestReel",
             "MountQualityTrace",
             "FID_DATA",
             "MountNormalTrace")
    #
    nv_tbls = c("Index",
                "Information")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading NON-NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    for (tbl in nv_tbls)
    {
        print(paste("reading NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_nv_table_from_db(db,
                                                   tbl,
                                                   nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}

sqlite_load_u0x <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("BRecg",
             "FILENAME_TO_IDS",
             "InspectionData",
             "MountPickupFeeder",
             "Count",
             "HeightCorrect",
             "MountExchangeReel",
             "MountPickupNozzle",
             "CycleTime",
             "Index",
             "MountLatestReel",
             "MountQualityTrace",
             "FID_DATA",
             "Information",
             "MountNormalTrace",
             "Time")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}

sqlite_load_nv_u0x <- function(db_name, nrows=0)
{
    if ((db_name == "") | is.na(db_name))
    {
        stop("DB NAME not set or zero-length")
    }
    #
    db_path = Sys.getenv("OMBT_DB_BASE_PATH")
    if ((db_path == "") | is.na(db_path))
    {
        stop("OMBT_DB_BASE_PATH not set or zero-length")
    }
    #
    db = sqlite_open_db(db_path, db_name)
    #
    tbls = c("BRecg",
             "FILENAME_TO_IDS",
             "MountPickupFeeder",
             "HeightCorrect",
             "MountExchangeReel",
             "MountPickupNozzle",
             "MountLatestReel",
             "MountQualityTrace",
             "FID_DATA",
             "MountNormalTrace")
    #
    nv_tbls = c("InspectionData",
                "Count",
                "CycleTime",
                "Index",
                "Information",
                "Time")
    #
    data = list()
    #
    for (tbl in tbls)
    {
        print(paste("reading NON-NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_table_from_db(db,
                                                tbl,
                                                nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    for (tbl in nv_tbls)
    {
        print(paste("reading NV table", tbl, "at", Sys.time()))
        data[[tbl]] = sqlite_load_nv_table_from_db(db,
                                                   tbl,
                                                   nrows=nrows)
        print(paste("done reading table", tbl, "at", Sys.time()))
    }
    #
    sqlite_close_db(db)
    #
    return(data)
}
